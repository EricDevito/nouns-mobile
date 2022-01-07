//
//  OffChainNounsFeed.ViewModel.swift
//  Nouns
//
//  Created by Mohammed Ibrahim on 2021-12-26.
//

import SwiftUI
import Services

extension OffChainNounsFeed {
  
  @MainActor
  final class ViewModel: ObservableObject {
    @Published var nouns = [Noun]()
    @Published var isFetching = false
    
    private let pageLimit = 20
    private let offChainNounsService: OffChainNounsService
    
    init(offChainNounsService: OffChainNounsService = AppCore.shared.offChainNounsService) {
      self.offChainNounsService = offChainNounsService
    }
    
    func fetchOffChainNouns() async {
      // when
      do {
        for try await nouns in offChainNounsService.nounsStoreDidChange(ascendingOrder: false) {
          self.nouns = nouns
        }
      } catch {
        print("Error: \(error)")
      }
    }
  }
}
