//
//  NetworkModels.swift
//  Prospects List
//
//  Created by Israel Manzo on 8/31/26.
//

import Foundation

// MARK: - Prospect List Response   
struct ProspectsResponse: Codable {
    let object: String
    let data: [Prospect]
    let page: Int
    let limit: Int
    let totalPages: Int
    let totalCount: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case object
        case data
        case page
        case limit
        case totalPages = "total_pages"
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

// MARK: - Prospect
struct Prospect: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let company: String
    let companyDomain: String?
    let title: String
    let seniority: String
    let source: String
    let campaign: String
    let lifecycleStage: String
    let signedUpAt: Date
    let attended: Bool
    let country: String
    let intentScore: Int
    let sourceMetadata: SourceMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case company
        case companyDomain = "company_domain"
        case title
        case seniority
        case source
        case campaign
        case lifecycleStage = "lifecycle_stage"
        case signedUpAt = "signed_up_at"
        case attended
        case country
        case intentScore = "intent_score"
        case sourceMetadata = "source_metadata"
    }

    var displayName: String {
        "\(firstName) \(lastName)"
    }

    var displayCompanyOrTitle: String {
        company.isEmpty ? title : company
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Prospect, rhs: Prospect) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Source Metadata (Variable by source)

enum SourceMetadata: Codable {
    case webinar(WebinarMetadata)
    case hubspot(HubspotMetadata)
    case other

    struct WebinarMetadata: Codable {
        let webinarTitle: String
        let minutesWatched: Int
        let askedQuestion: Bool

        enum CodingKeys: String, CodingKey {
            case webinarTitle = "webinar_title"
            case minutesWatched = "minutes_watched"
            case askedQuestion = "asked_question"
        }
    }

    struct HubspotMetadata: Codable {
        let formName: String
        let touchChannel: String

        enum CodingKeys: String, CodingKey {
            case formName = "form_name"
            case touchChannel = "touch_channel"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        if let webinarTitle = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "webinar_title")!) {
            let minutesWatched = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "minutes_watched")!)
            let askedQuestion = try container.decode(Bool.self, forKey: DynamicCodingKeys(stringValue: "asked_question")!)
            self = .webinar(WebinarMetadata(webinarTitle: webinarTitle, minutesWatched: minutesWatched, askedQuestion: askedQuestion))
        } else if let formName = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "form_name")!) {
            let touchChannel = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "touch_channel")!)
            self = .hubspot(HubspotMetadata(formName: formName, touchChannel: touchChannel))
        } else {
            self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        switch self {
        case .webinar(let metadata):
            try container.encode(metadata.webinarTitle, forKey: DynamicCodingKeys(stringValue: "webinar_title")!)
            try container.encode(metadata.minutesWatched, forKey: DynamicCodingKeys(stringValue: "minutes_watched")!)
            try container.encode(metadata.askedQuestion, forKey: DynamicCodingKeys(stringValue: "asked_question")!)
        case .hubspot(let metadata):
            try container.encode(metadata.formName, forKey: DynamicCodingKeys(stringValue: "form_name")!)
            try container.encode(metadata.touchChannel, forKey: DynamicCodingKeys(stringValue: "touch_channel")!)
        case .other:
            break
        }
    }
}

// MARK: - Dynamic Coding Keys

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// MARK: - Enrichment Response

struct EnrichmentResponse: Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let company: String?
    let industry: String?
    let employeeCount: Int?
    let buyingAuthority: String?
    let matchConfidence: Double?
    let linkedinUrl: String?
    let directDial: String?
    let securityBudgetUsd: Int?
    let techStack: [String]?
    let complianceFrameworks: [String]?
    let recentBreachDisclosed: Bool?
    let executiveExposureScore: Int?
    let hqLocation: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case company
        case industry
        case employeeCount = "employee_count"
        case buyingAuthority = "buying_authority"
        case matchConfidence = "match_confidence"
        case linkedinUrl = "linkedin_url"
        case directDial = "direct_dial"
        case securityBudgetUsd = "security_budget_usd"
        case techStack = "tech_stack"
        case complianceFrameworks = "compliance_frameworks"
        case recentBreachDisclosed = "recent_breach_disclosed"
        case executiveExposureScore = "executive_exposure_score"
        case hqLocation = "hq_location"
    }
}
