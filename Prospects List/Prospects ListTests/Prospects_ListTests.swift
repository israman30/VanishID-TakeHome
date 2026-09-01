//
//  Prospects_ListTests.swift
//  Prospects ListTests
//
//  Created by Israel Manzo on 8/31/26.
//

import XCTest
@testable import Prospects_List

final class Prospects_ListTests: XCTestCase {
    var mockData: MockServices!
    
    override func setUpWithError() throws {
        mockData = MockServices()
    }
    
    override func tearDownWithError() throws {
        mockData = nil
    }
    
    func testFetchProspects_Success() async throws {
        mockData.shouldFail = false
        let response = try await mockData.fetchProspects(page: 1, limit: 10)
        XCTAssertFalse(mockData.prospects.isEmpty, "Prospects list should not be empty")
        XCTAssertEqual(response.page, 1, "Page number should match request")
    }
    
    func testFetchProspects_Failure() async {
        mockData.shouldFail = true
        do {
            _ = try await mockData.fetchProspects(page: 1, limit: 10)
            XCTFail("Expected fetchProspects to throw an error, but it succeeded.")
        } catch let error as NetworkError {
            XCTAssertEqual(error.errorDescription, "Unauthorized. Invalid API key.")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDecodesProspectsWithFractionalDatesAndNumericIds() throws {
        let json = """
        {
          "object": "list",
          "data": [
            {
              "id": 42,
              "first_name": "Ada",
              "last_name": "Lovelace",
              "email": "ada@example.com",
              "company": null,
              "title": "Analyst",
              "source": "webinar",
              "signed_up_at": "2026-08-31T16:05:22.123Z",
              "intent_score": 8.7,
              "source_metadata": { "webinar_title": "Privacy 101" }
            }
          ],
          "page": 1,
          "has_more": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: string)!
        }

        let response = try decoder.decode(ProspectsResponse.self, from: json)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "42")
        XCTAssertEqual(response.data[0].displayName, "Ada Lovelace")
        XCTAssertEqual(response.data[0].intentScore, 8)
    }
}

final class MockServices: NetworkServiceProtocol {
    var shouldFail = false
    var prospects = [Prospect]()
    
    func fetchProspects(page: Int, limit: Int) async throws -> ProspectsResponse {
        ProspectsResponse(data: [])
    }
    
    func enrichProspect(email: String) async throws -> EnrichmentResponse {
        EnrichmentResponse(id: "xoxox", email: "john@mail.com", firstName: "Johs", lastName: "Doe", company: "Oracle", industry: "Tech", employeeCount: 20, buyingAuthority: "", matchConfidence: nil, linkedinUrl: "", directDial: "", securityBudgetUsd: nil, techStack: [], complianceFrameworks: [], recentBreachDisclosed: false, executiveExposureScore: 5, hqLocation: "")
    }
    
}
