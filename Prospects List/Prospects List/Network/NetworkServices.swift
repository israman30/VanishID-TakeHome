//
//  NetworkServices.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation

// MARK: - Network Service Protocol
/// Defines the core contract for network operations related to prospect management and data enrichment.
///
/// `NetworkServiceProtocol` leverages modern Swift Concurrency (`async/await`) to handle asynchronous
/// API requests for fetching paginated prospects and enriching individual contact records.
protocol NetworkServiceProtocol {
    /// Fetches a paginated list of prospects from the server.
        /// - Parameters:
        ///   - page: The page number to request (typically 1-indexed).
        ///   - limit: The maximum number of prospect records to return per page.
        /// - Returns: A `ProspectsResponse` containing the array of prospects and pagination metadata.
        /// - Throws: `NetworkError` if the network request fails, times out, or encounters decoding issues.
    func fetchProspects(page: Int, limit: Int) async throws -> ProspectsResponse
    /// Requests enriched professional and technical intelligence for a specific email address.
        /// - Parameter email: The target prospect's email address used for lookup and enrichment.
        /// - Returns: An `EnrichmentResponse` containing organizational, technology stack, and compliance data.
        /// - Throws: `NetworkError` if the lookup fails, returns a 404, or encounters unauthorized access.
    func enrichProspect(email: String) async throws -> EnrichmentResponse
}

// MARK: - Network Configuration
struct NetworkConfig {
    let baseURL: URL
    let apiKey: String
    let timeoutInterval: TimeInterval

    static let `default` = NetworkConfig(
        // `localhost` is treated as a local ATS exception more reliably than 127.0.0.1.
        baseURL: URL(string: "http://localhost:8080")!,
        apiKey: "gtm-takehome-2026",
        timeoutInterval: 30
    )
}

// MARK: - Network Service Implementation
/// A robust network service actor confined to the main execution context that handles API communication.
///
/// `NetworkService` conforms to `NetworkServiceProtocol` to fetch paginated prospects and enrich
/// contact data using modern Swift Concurrency (`async/await`), custom date decoding, and detailed error mapping.
@MainActor
final class NetworkService: NetworkServiceProtocol {
    private let config: NetworkConfig
    private let decoder = JSONDecoder()
    private let session: URLSession

    /// Initializes the network service with required configuration and an optional session.
        /// - Parameters:
        ///   - config: The network configuration object containing endpoint URLs and API keys.
        ///   - session: The `URLSession` instance to use for network calls. Defaults to `.shared`.
    init(config: NetworkConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        setupDecoder()
    }

    private func setupDecoder() {
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
    }

    // MARK: - Fetch Prospects
    /// Fetches a paginated list of prospects from the `/v1/prospects` endpoint.
        /// - Parameters:
        ///   - page: The target page number.
        ///   - limit: The maximum number of items per page.
        /// - Returns: A decoded `ProspectsResponse` containing the list of prospects and metadata.
        /// - Throws: `NetworkError` if URL construction, transport, or decoding fails.
    func fetchProspects(page: Int, limit: Int) async throws -> ProspectsResponse {
        var components = URLComponents(
            url: config.baseURL.appending(path: "v1/prospects"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        return try await performRequest(ProspectsResponse.self, url: url)
    }

    // MARK: - Enrich Prospect
    /// Requests enrichment data for a specific contact email from the `/v1/enrich` endpoint.
        /// - Parameter email: The email address to query.
        /// - Returns: A decoded `EnrichmentResponse` containing organizational and technical intelligence.
        /// - Throws: `NetworkError` if the request fails or returns an error status code.
    func enrichProspect(email: String) async throws -> EnrichmentResponse {
        var components = URLComponents(
            url: config.baseURL.appending(path: "v1/enrich"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "email", value: email),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        return try await performRequest(EnrichmentResponse.self, url: url)
    }

    // MARK: - Perform Request
    /// Generic helper method to execute an HTTP GET request, handle transport and error status codes, and decode the response.
        /// - Parameters:
        ///   - type: The expected Decodable model type.
        ///   - url: The fully constructed request URL.
        /// - Returns: The decoded model instance.
        /// - Throws: `NetworkError` mapped from transport failures, bad status codes, or decoding exceptions.
    private func performRequest<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = config.timeoutInterval

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw mapTransportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidRequest
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(Self.decodingDescription(error))
        }
    }

    // Maps low-level `URLError` transport failures into descriptive, user-friendly `NetworkError` cases.
        /// - Parameter error: The raw transport error caught during execution.
        /// - Returns: A localized `NetworkError` with setup instructions if applicable.
    private func mapTransportError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut, .dnsLookupFailed:
                return .connectionFailed(
                    "Could not reach \(config.baseURL.absoluteString). Make sure the take-home API is running. (\(urlError.localizedDescription))"
                )
            case .appTransportSecurityRequiresSecureConnection:
                return .connectionFailed(
                    "App Transport Security blocked the HTTP request to \(config.baseURL.absoluteString)."
                )
            default:
                return .connectionFailed(urlError.localizedDescription)
            }
        }

        return .unknown(error)
    }

    /// Inspects error response payloads and HTTP status codes to generate precise domain errors.
        /// - Parameters:
        ///   - data: The raw error response body returned by the server.
        ///   - statusCode: The HTTP response status code.
        ///   - headers: The HTTP header fields (used for rate limit retry intervals).
        /// - Returns: A corresponding `NetworkError` instance.
    private func handleErrorResponse(data: Data, statusCode: Int, headers: [AnyHashable: Any]) throws -> NetworkError {
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

    /// Custom date decoding strategy supporting numeric timestamps (seconds or milliseconds) and multiple ISO/POSIX string formats.
        /// - Parameter decoder: The decoder instance providing the single value container.
        /// - Returns: A parsed `Date` object.
        /// - Throws: `DecodingError` if the value matches no supported date format.
    private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()

        if let timestamp = try? container.decode(Double.self) {
            let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
            return Date(timeIntervalSince1970: seconds)
        }

        let string = try container.decode(String.self)

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) {
            return date
        }

        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: string) {
            return date
        }

        let posix = DateFormatter()
        posix.locale = Locale(identifier: "en_US_POSIX")
        posix.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            posix.dateFormat = format
            if let date = posix.date(from: string) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
    }

    /// Converts low-level Swift `DecodingError` instances into clean, readable debug descriptions.
        /// - Parameter error: The caught error.
        /// - Returns: A human-readable description string specifying missing keys, type mismatches, or corrupted data paths.
    private static func decodingDescription(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch (\(type)) at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Null \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}
