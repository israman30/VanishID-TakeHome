//
//  ProspectViewModel.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation
import Combine

// MARK: - App State
enum AppState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

@MainActor
final class ProspectViewModel: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var prospects: [Prospect] = []
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var hasMorePages: Bool = true
    @Published private(set) var isLoadingMore: Bool = false
    
    private let networkService: NetworkServiceProtocol
    
    private let pageSize = 20
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }
    
    // MARK: - Fetch Initial Prospects
    func fetchProspects() async {
        state = .loading
        currentPage = 1
        prospects.removeAll()
        
        do {
            let response = try await networkService.fetchProspects(
                page: currentPage,
                limit: pageSize
            )
            
            prospects = response.data
            hasMorePages = response.hasMore
            state = .loaded
            
        } catch let error as NetworkError {
            state = .error(error.errorDescription ?? "Failed to load prospects")
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Load More Prospects
    func loadMoreProspects() async {
        guard !isLoadingMore, hasMorePages, state == .loaded else { return }
        
        isLoadingMore = true
        
        do {
            let nextPage = currentPage + 1
            let response = try await networkService.fetchProspects(
                page: nextPage,
                limit: pageSize
            )
            
            prospects.append(contentsOf: response.data)
            currentPage = nextPage
            hasMorePages = response.hasMore
            
        } catch let error as NetworkError {
            state = .error(error.errorDescription ?? "Failed to load more prospects")
        } catch {
            state = .error(error.localizedDescription)
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Retry
    func retry() async {
        await fetchProspects()
    }
}
