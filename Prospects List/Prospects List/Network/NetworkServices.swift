//
//  NetworkServices.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol {
    func fetchProspects(page: Int, limit: Int) async throws -> ProspectsResponse
    func enrichProspect(email: String) async throws -> EnrichmentResponse
}

// MARK: - Network Configuration

struct NetworkConfig {
    let baseURL: URL
    let apiKey: String
    let timeoutInterval: TimeInterval

    static let `default` = NetworkConfig(
        baseURL: URL(string: "http://127.0.0.1:8080")!,
        apiKey: "gtm-takehome-2026",
        timeoutInterval: 30
    )
}

// MARK: - Network Service Implementation

@MainActor
final class NetworkService: NetworkServiceProtocol {
    private let config: NetworkConfig
//    private let logger = NetworkLogger.shared
    private let decoder = JSONDecoder()

    init(config: NetworkConfig) {
        self.config = config
        setupDecoder()
    }

    private func setupDecoder() {
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Fetch Prospects

    func fetchProspects(page: Int, limit: Int) async throws -> ProspectsResponse {
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("v1/prospects"),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let response = try await performRequest(ProspectsResponse.self, url: url)
//        logger.log(.success, message: "Fetched \(response.data.count) prospects")
        return response
    }

    // MARK: - Enrich Prospect

    func enrichProspect(email: String) async throws -> EnrichmentResponse {
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("v1/enrich"),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "email", value: email),
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let response = try await performRequest(EnrichmentResponse.self, url: url)
//        logger.log(.success, message: "Enriched prospect: \(email)")
        return response
    }

    // MARK: - Perform Request

    private func performRequest<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = config.timeoutInterval

//        logger.log(.request, message: "GET \(url.path)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidRequest
        }

//        logger.log(.response, message: "Status: \(httpResponse.statusCode)")

        // Handle error responses
        if !(200...299).contains(httpResponse.statusCode) {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }

        // Decode successful response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
//            logger.logError(error, url: url)
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    private func handleErrorResponse(data: Data, statusCode: Int, headers: [AnyHashable: Any]) throws -> NetworkError {
        // Try to decode error response
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            let detail = errorResponse.error

            switch statusCode {
            case 400:
                return .badRequest(fieldPath: detail.fieldPath, message: detail.message)
            case 401:
                return .unauthorized
            case 404:
                return .notFound(message: detail.message)
            case 429:
                let retryAfter = (headers["Retry-After"] as? String).flatMap(Int.init)
                return .rateLimited(retryAfter: retryAfter)
            default:
                return .httpError(statusCode: statusCode, message: detail.message)
            }
        }

        // Fallback for responses without error detail
        switch statusCode {
        case 401:
            return .unauthorized
        case 404:
            return .notFound(message: "Resource not found")
        case 429:
            let retryAfter = (headers["Retry-After"] as? String).flatMap(Int.init)
            return .rateLimited(retryAfter: retryAfter)
        default:
            return .httpError(statusCode: statusCode, message: HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }
}

