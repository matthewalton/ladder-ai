import Foundation

/// Carried into the repair request so the service is told what to fix.
struct TailorValidationFailure: Error, Equatable {
    var reason: String
}

struct TailorResult: Equatable, Sendable, Decodable {
    /// The generated CV summary — per application, never stored on the
    /// Profile (decisions/0006).
    var summary: String
    var selections: [TailorSelection]
    /// Whole projects selected by `p…` id (decisions/0007); absent decodes
    /// as none selected.
    var projects: [String]
    var gaps: [String]
    var rationale: String

    private enum CodingKeys: String, CodingKey {
        case summary, selections, projects, gaps, rationale
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        selections = try container.decode([TailorSelection].self, forKey: .selections)
        projects = try container.decodeIfPresent([String].self, forKey: .projects) ?? []
        gaps = try container.decode([String].self, forKey: .gaps)
        rationale = try container.decode(String.self, forKey: .rationale)
    }

    init(json: Data, validAchievementIDs: Set<String>, validProjectIDs: Set<String> = []) throws {
        // A whole-response fence is presentation, not content — stripped so a
        // formatting quirk never consumes the single repair request.
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(TailorResult.self, from: json)
        } catch {
            throw TailorValidationFailure(
                reason: "The response did not match the tailor result schema: \(error)"
            )
        }
        let unknown = selections.map(\.achievementID).filter { !validAchievementIDs.contains($0) }
        guard unknown.isEmpty else {
            throw TailorValidationFailure(
                reason: "Selections reference achievement ids not in the payload: \(unknown.joined(separator: ", ")). Use only the `a…` ids given; whole projects go in `projects`."
            )
        }
        let unknownProjects = projects.filter { !validProjectIDs.contains($0) }
        guard unknownProjects.isEmpty else {
            throw TailorValidationFailure(
                reason: "Projects reference ids not in the payload: \(unknownProjects.joined(separator: ", ")). Use only the `p…` ids given."
            )
        }
    }
}

struct TailorSelection: Equatable, Sendable, Decodable {
    var achievementID: String
    /// The talking point expanded into one polished CV bullet.
    var bullet: String
}
