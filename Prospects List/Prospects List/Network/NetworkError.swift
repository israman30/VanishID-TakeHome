//
//  NetworkError.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation

// MARK: - Network Error
/// Represents comprehensive network, decoding, and server-side errors encountered during API requests.
///
/// `NetworkError` conforms to `LocalizedError` to provide user-facing error descriptions,
/// contextual recovery suggestions, and built-in rules for retry logic.
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidRequest
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case rateLimited(retryAfter: Int?)
    case notFound(message: String)
    case unauthorized
    case badRequest(fieldPath: String?, message: String)
    case connectionFailed(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest:
            return "Invalid request"
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg)"
        case .decodingError(let msg):
            return "Decoding error: \(msg)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry in \(seconds) seconds."
            }
            return "Rate limited. Please try again later."
        case .notFound(let msg):
            return msg
        case .unauthorized:
            return "Unauthorized. Invalid API key."
        case .badRequest(let path, let msg):
            if let path {
                return "Bad request (\(path)): \(msg)"
            }
            return "Bad request: \(msg)"
        case .connectionFailed(let msg):
            return msg
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .rateLimited:
            return "Please wait and try again."
        case .unauthorized:
            return "Check your API key configuration."
        case .notFound:
            return "This prospect may not have enrichment data available."
        case .connectionFailed:
            return "Start the local API on port 8080, then pull to retry."
        default:
            return "Please try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited:
            return true
        case .httpError(let code, _):
            return code >= 500 || code == 429
        default:
            return false
        }
    }
}

// MARK: - API Error Response
struct APIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let fieldPath: String?

        enum CodingKeys: String, CodingKey {
            case code
            case message
            case fieldPath = "field_path"
        }
    }
}
