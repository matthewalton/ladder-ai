import Foundation

/// The structure the intelligence service returns for an extracted CV (slice
/// CONTEXT.md: proposal) — held in memory for review, never persisted. Scope
/// is roles, achievements, and skills only; everything else arrives as a
/// not-imported section (decisions/0002).
struct ImportProposal: Equatable, Sendable, Decodable {
    var roles: [ProposedRole]
    var notImportedSections: [NotImportedSection]

    /// Schema validation: JSON the decoder rejects fails the import
    /// (SPEC.md [CVIMPORT-10]).
    init(json: Data) throws {
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
        } catch {
            throw ImportError.proposalInvalid
        }
    }

    /// Proposal dates are month-resolution ("2021-04"), as CVs state them.
    private static func parseMonth(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: raw)
    }
}

struct ProposedRole: Equatable, Sendable, Decodable {
    var company: String
    var title: String
    var start: Date
    var end: Date?  // nil = current role, as in the Role model
    var achievements: [ProposedAchievement]
}

struct ProposedAchievement: Equatable, Sendable, Decodable {
    var text: String
    var impactMetric: String?
    var tech: [String]
    var skills: [String]
}

/// CV content outside the import scope — listed in review so nothing is
/// silently dropped, never merged (SPEC.md [CVIMPORT-9]).
struct NotImportedSection: Equatable, Sendable, Decodable {
    var name: String
    var content: String
}
