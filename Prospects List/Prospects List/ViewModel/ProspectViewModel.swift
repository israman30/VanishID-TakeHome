//
//  ProspectViewModel.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation

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
