import Foundation

/// The structure the intelligence service returns for an extracted CV —
/// held in memory for review, never persisted. Covers the whole CV
/// (decisions/0008): identity, roles, education, projects, interests, plus
/// not-imported sections.
struct ImportProposal: Equatable, Sendable, Decodable {
    var identity: ProposedIdentity
    var roles: [ProposedRole]
    var education: [ProposedEducation]
    var projects: [ProposedProject]
    var interests: [String]
    var notImportedSections: [NotImportedSection]

    init(json: Data) throws {
        let json = FencedJSON.stripped(from: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ImportProposal.parseMonth(raw) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "expected a yyyy-MM date, got \(raw)"
                ))
            }
            return date
        }
        do {
            self = try decoder.decode(ImportProposal.self, from: json)
        } catch let error as DecodingError {
            throw ImportError.proposalInvalid(reason: Self.reason(for: error))
        } catch {
            throw ImportError.proposalInvalid(reason: "the response did not match the proposal schema")
        }
        // A fresh Profile needs a name ([CVIMPORT-23], [PROFILE-3]) — reject
        // here so the failure carries its reason, not at replace time.
        if identity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ImportError.proposalInvalid(reason: "'identity.name' is empty — a CV always names its owner")
        }
    }

    private static func reason(for error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "the proposal is missing '\(path(context.codingPath, then: key))'"
        case .typeMismatch(_, let context):
            "'\(path(context.codingPath))' is not the expected type"
        case .valueNotFound(_, let context):
            "'\(path(context.codingPath))' is null where a value is required"
        case .dataCorrupted(let context) where context.codingPath.isEmpty:
            "the response was not valid JSON"
        case .dataCorrupted(let context):
            "'\(path(context.codingPath))' is invalid: \(context.debugDescription)"
        @unknown default:
            "the response did not match the proposal schema"
        }
    }

    /// "roles[0].achievements[1].text" from a coding path.
    private static func path(_ codingPath: [any CodingKey], then last: (any CodingKey)? = nil) -> String {
        var rendered = ""
        for key in codingPath + [last].compactMap(\.self) {
            if let index = key.intValue {
                rendered += "[\(index)]"
            } else {
                rendered += rendered.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return rendered.isEmpty ? "the proposal" : rendered
    }

    /// CVs state dates at month resolution ("2021-04").
    private static func parseMonth(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: raw)
    }
}

/// Identity always travels with the confirmation — it is not a per-item
/// reviewable ([CVIMPORT-23]).
struct ProposedIdentity: Equatable, Sendable, Decodable {
    var name: String
    var headline: String?
    var contact: ProposedContact
}

/// Fields the CV lacks arrive as null and land as empty strings.
struct ProposedContact: Equatable, Sendable, Decodable {
    var email: String?
    var phone: String?
    var location: String?
    var link: String?
}

struct ProposedRole: Equatable, Sendable, Decodable {
    var company: String
    var title: String
    var start: Date
    var end: Date?  // nil = current role
    var achievements: [ProposedAchievement]
}

struct ProposedAchievement: Equatable, Sendable, Decodable {
    var text: String
    var impactMetric: String?
    var tech: [String]
    var skills: [String]
}

struct ProposedEducation: Equatable, Sendable, Decodable {
    var institution: String
    var qualification: String
    var start: Date
    var end: Date?  // nil = in progress
    var detail: String?
}

/// Projects propose a description and skills, not points (decisions/0010;
/// Profile decisions/0009).
struct ProposedProject: Equatable, Sendable, Decodable {
    var name: String
    var link: String?
    var summary: String?
    var description: String?
    var skills: [String]
}

/// CV content outside the import scope — the summary paragraph,
/// certifications — listed in review, never merged ([CVIMPORT-27]).
struct NotImportedSection: Equatable, Sendable, Decodable {
    var name: String
    var content: String
}
