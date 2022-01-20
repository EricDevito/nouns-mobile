//
//  Nouns.swift
//  Nouns DAO
//
//  Created by Ziad Tamim on 20.10.21.
//

import Foundation
import Combine
import CoreData
import web3
import BigInt

/// `onChainNounsService` request error.
public enum OnChainNounsRequestError: Error {
  
  /// The response is empty
  case noData
}

/// Service allows interacting with the `OnChain Nouns`.
public protocol OnChainNounsService: AnyObject {
  
  /// Asynchronously fetch the Nouns treasury from the eth network.
  ///
  /// - Returns: The total amount stored of `Ether + staked Ether in Lido`.
  func fetchTreasury() async throws -> String
  
  /// Asynchronously fetches the list of the settled Nouns from the chain.
  ///
  /// - Parameters:
  ///   - limit: A limit up to the  `n` elements from the list.
  ///   - cursor: A cursor for use in pagination.
  ///
  /// - Returns: A list of `Noun` type  instance or throw an error.
  func fetchSettledNouns(limit: Int, after cursor: Int) async throws -> [Noun]
  
  /// Asynchronously fetches the list of auction settled from the chain.
  ///
  /// - Parameters:
  ///   - settled: Whether or not the auction has been settled.
  ///   - limit: A limit up to the  `n` elements from the list.
  ///   - cursor: A cursor for use in pagination.
  ///
  /// - Returns: A list of `Auction` type  instance or throw an error.
  func fetchAuctions(settled: Bool, limit: Int, cursor: Int) async throws -> [Auction]
  
  /// An asynchronous sequence that  produce the live auction and
  /// react to its properties changes
  ///
  /// - Returns: A `Auction` instance or throw an error.
  func liveAuctionStateDidChange() -> AsyncStream<Auction>
  
  /// An asynchronous sequence that  produce the last settled auction added.
  ///
  /// - Returns: A `Auction` instance or throw an error.
  func settledAuctionsDidChange() -> AsyncStream<Auction>
  
  /// Asynchronously fetches the list of Activities of a given Noun from the chain.
  ///
  /// - Parameters:
  ///   - nounID: A settled `Noun` identifier.
  ///   - limit: A limit up to the  `n` elements from the list.
  ///   - cursor: A cursor for use in pagination.
  ///
  /// - Returns: A list of `Activity` type  instance or throw an error.
  func fetchActivity(for nounID: String, limit: Int, after cursor: Int) async throws -> [Vote]
  
  /// Asynchronously fetches the list of Bids of a given Noun from the chain.
  ///
  /// - Parameters:
  ///   - nounID: A settled `Noun` identifier.
  ///
  /// - Returns: A list of `Bid` type  instance or throw an error.
  func fetchBids(for nounID: String, limit: Int, after cursor: Int) async throws -> [Bid]
  
  /// Asynchronously fetches the list of proposals for all type status.
  ///
  /// - Parameters:
  ///   - limit: A limit up to the  `n` elements from the list.
  ///   - cursor: A cursor for use in pagination.
  ///
  /// - Returns: A list of `Proposal` type  instance or throw an error.
  func fetchProposals(limit: Int, after cursor: Int) async throws -> [Proposal]
}

/// Concrete implementation of the `onChainNounsService` using `TheGraph` Service.
public class TheGraphNounsProvider: OnChainNounsService {
  private let graphQLClient: GraphQL
  
  /// The ethereum client layer provided by `web3swift` package
  private let ethereumClient = EthereumClient(url: CloudConfiguration.Infura.mainnet.url!)
  
  /// Live auction watcher for all properties changes.
  private var liveAuctionListener: ShortPolling<Auction>?
  
  /// Watcher for newly added settled auctions.
  private var settledAuctionsListener: ShortPolling<Auction>?
  
  /// NounsDAOExecutor contract address.
  private enum Address {
    static let ethDAOExecutor = "0x0BC3807Ec262cB779b38D65b38158acC3bfedE10"
    static let stEthDAOExecutor = "0xae7ab96520de3a18e5e111b5eaab095312d7fe84"
  }
  
  public init(graphQLClient: GraphQL = GraphQLClient()) {
    self.graphQLClient = graphQLClient
  }
  
  private func ethTreasury() async throws -> BigUInt {
    try await withCheckedThrowingContinuation { continuation in
      ethereumClient.eth_getBalance(
        address: EthereumAddress(Address.ethDAOExecutor),
        block: .Latest
      ) { error, balance in
        if let error = error {
          return continuation.resume(throwing: error)
        }
        
        if let balance = balance {
          continuation.resume(returning: balance)
        }
      }
    }
  }
  
  private func stEthTreasury() async throws -> BigUInt {
    try await withCheckedThrowingContinuation { continuation in
      let function = ERC20Functions.balanceOf(contract: EthereumAddress(Address.stEthDAOExecutor),account: EthereumAddress(Address.ethDAOExecutor))
      
      function.call(
        withClient: ethereumClient,
        responseType: ERC20Responses.balanceResponse.self
      ) { error, balanceResponse in
        if let error = error {
          return continuation.resume(throwing: error)
        }
        
        if let balanceResponse = balanceResponse {
          continuation.resume(returning: balanceResponse.value)
        }
      }
    }
  }
  
  public func fetchTreasury() async throws -> String {
    async let eth = ethTreasury()
    async let stEth = stEthTreasury()
    
    // To match the nouns.wtf website, eth and stEth are compared as a
    // 1:1 ratio and as such are added together without conversion.
    // The precise value is slightly different
    let (ethValue, stEthValue) = try await (eth, stEth)
    return String(ethValue + stEthValue)
  }
  
  public func fetchSettledNouns(limit: Int, after cursor: Int) async throws -> [Noun] {
    let query = NounsSubgraph.NounsQuery(first: limit, skip: cursor)
    let page: Page<[Noun]> = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )
    return page.data
  }
  
  public func fetchAuctions(settled: Bool, limit: Int, cursor: Int) async throws -> [Auction] {
    let query = NounsSubgraph.AutionsQuery(settled: settled, first: limit, skip: cursor)
    let page: Page<[Auction]> = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )
    return page.data
  }
  
  public func settledAuctionsDidChange() -> AsyncStream<Auction> {
    AsyncStream { [weak self] continuation in
      guard let self = self else { return }
      
      if self.settledAuctionsListener == nil {
        self.settledAuctionsListener = ShortPolling(
          continuation: continuation,
          action: {
            
            guard let auction = try await self.fetchAuctions(
              settled: true,
              limit: 1,
              cursor: 0
            ).first else {
              throw OnChainNounsRequestError.noData
            }
            
            return auction
          }
        )
      }
      
      self.settledAuctionsListener?.startPolling()
    }
  }
  
  public func liveAuctionStateDidChange() -> AsyncStream<Auction> {
    AsyncStream { [weak self] continuation in
      guard let self = self else { return }
      
      if self.liveAuctionListener == nil {
        self.liveAuctionListener = ShortPolling(
          continuation: continuation,
          action: { try await self.fetchLiveAuction() }
        )
      }
      
      self.liveAuctionListener?.startPolling()
    }
  }
  
  private func fetchLiveAuction() async throws -> Auction {
    let query = NounsSubgraph.LiveAuctionSubscription()
    let page: Page<[Auction]>? = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )

    guard let auction = page?.data.first else {
      throw OnChainNounsRequestError.noData
    }
    
    return auction
  }
  
  public func fetchActivity(for nounID: String, limit: Int, after cursor: Int) async throws -> [Vote] {
    let query = NounsSubgraph.ActivitiesQuery(nounID: nounID, first: limit, skip: cursor)
    let page: Page<[Vote]> = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )
    return page.data
  }
  
  public func fetchProposals(limit: Int, after cursor: Int) async throws -> [Proposal] {
    let query = NounsSubgraph.ProposalsQuery(first: limit, skip: cursor)
    let page: Page<[Proposal]> = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )
    return page.data
  }
  
  public func fetchBids(for nounID: String, limit: Int, after cursor: Int) async throws -> [Bid] {
    let query = NounsSubgraph.BidsQuery(nounID: nounID, first: limit, skip: cursor)
    let page: Page<[Bid]> = try await graphQLClient.fetch(
      query,
      cachePolicy: .returnCacheDataAndFetch
    )
    return page.data
  }
}
