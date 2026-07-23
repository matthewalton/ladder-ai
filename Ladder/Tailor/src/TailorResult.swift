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
    /// The per-CV skill grouping (decisions/0009); absent decodes as no
    /// grouping — the rendered CV then has no skills table.
    var skillCategories: [SkillCategory]
    var gaps: [String]
    var rationale: String

    private enum CodingKeys: String, CodingKey {
        case summary, selections, projects, skillCategories, gaps, rationale
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        selections = try container.decode([TailorSelection].self, forKey: .selections)
        projects = try container.decodeIfPresent([String].self, forKey: .projects) ?? []
        skillCategories =
            try container.decodeIfPresent([SkillCategory].self, forKey: .skillCategories) ?? []
        gaps = try container.decode([String].self, forKey: .gaps)
        rationale = try container.decode(String.self, forKey: .rationale)
    }

    init(
        json: Data,
        validAchievementIDs: Set<String>,
        validProjectIDs: Set<String> = [],
        tagNamesByID: [String: [String]] = [:]
    ) throws {
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
        // The vocabulary bound (decisions/0009; CVExport decisions/0004):
        // every grouped skill is a Tag on the selected content — the union is
        // grouped, never extended. Case-insensitive so a casing echo never
        // costs the repair.
        let selectedIDs = selections.map(\.achievementID) + projects
        let allowedSkills = Set(
            selectedIDs.flatMap { tagNamesByID[$0] ?? [] }.map { $0.lowercased() }
        )
        let strays = skillCategories
            .flatMap(\.skills)
            .filter { !allowedSkills.contains($0.lowercased()) }
        guard strays.isEmpty else {
            throw TailorValidationFailure(
                reason: "skillCategories name skills not on the selected content: \(strays.joined(separator: ", ")). Group only the `tags` of the achievements and projects you selected."
            )
        }
    }
}

struct TailorSelection: Equatable, Sendable, Decodable {
    var achievementID: String
    /// The talking point expanded into one polished CV bullet.
    var bullet: String
}

/// One named group of the selection's skills — per-CV and transient, never
/// stored on `SkillTag` (decisions/0009).
struct SkillCategory: Equatable, Sendable, Decodable {
    var name: String
    var skills: [String]

    init(name: String, skills: [String]) {
        self.name = name
        self.skills = skills
    }
}
