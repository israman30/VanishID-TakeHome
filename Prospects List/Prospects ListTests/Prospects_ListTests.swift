//
//  Prospects_ListTests.swift
//  Prospects ListTests
//
//  Created by Israel Manzo on 8/31/26.
//

import XCTest
@testable import Prospects_List

final class Prospects_ListTests: XCTestCase {
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
