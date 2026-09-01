//
//  ContentView.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import SwiftUI

struct ContentView: View {
//    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel: ProspectViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: ProspectViewModel(networkService: NetworkService(config: NetworkConfig.default)))
    }
    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .idle, .loading:
                    loadingView
                    
                case .loaded:
                    listContent
                    
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Prospects")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchProspects()
            }
        }
    }
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading prospects...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listContent: some View {
        List(viewModel.prospects) { prospect in
            NavigationLink(value: prospect) {
                ProspectRowView(prospect: prospect)
            }
            .onAppear {
                if prospect == viewModel.prospects.last {
                    Task {
                        await viewModel.loadMoreProspects()
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.prospects.isEmpty {
                ContentUnavailableView(
                    "No prospects",
                    systemImage: "person.3",
                    description: Text("The API returned no rows. Confirm the local server is running on port 8080.")
                )
            } else if viewModel.isLoadingMore {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
        .navigationDestination(for: Prospect.self) { prospect in
//            ProspectDetailView(prospect: prospect)
        }
    }
}

#Preview {
    ContentView()
}

struct ProspectRowView: View {
    let prospect: Prospect

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prospect.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(prospect.displayCompanyOrTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Intent: \(prospect.intentScore)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text(prospect.source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
