//
//  NounActivityFeed.ViewModel.swift
//  Nouns
//
//  Created by Ziad Tamim on 17.12.21.
//

import Foundation
import Services

extension NounActivityFeed {
  
  final class ViewModel: ObservableObject {
    let auction: Auction
    
    @Published var votes = [Vote]()
    @Published var isLoading = false
    @Published var shouldLoadMore = true
    @Published var failedToLoadMore = false
    
    private let pageLimit = 20
    private let service: OnChainNounsService
    
    /// Only show the empty placeholder when there are no votes and when the data source is not loading
    /// This occurs mainly on initial appearance, before any votes have loaded
    var isEmpty: Bool {
      votes.isEmpty && !isLoading
    }
    
    init(
      auction: Auction,
      service: OnChainNounsService = AppCore.shared.onChainNounsService
    ) {
      self.auction = auction
      self.service = service
    }
    
    var owner: String {
      auction.noun.owner.id
    }
    
    @MainActor
    func fetchActivity() async {
      failedToLoadMore = false
      
      do {
        isLoading = true
        
        let votes = try await service.fetchActivity(
          for: auction.noun.id,
             limit: pageLimit,
             after: votes.count
        )
        
        shouldLoadMore = votes.hasNext
        
        self.votes += votes.data
        
      } catch {
        failedToLoadMore = true
      }
      
      isLoading = false
    }
  }
}
