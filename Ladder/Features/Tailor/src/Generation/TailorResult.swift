import Foundation

struct TailorValidationFailure: Error, Equatable {
    var reason: String
}

struct TailorResult: Equatable, Sendable, Decodable {
    var summary: String
    var selections: [TailorSelection]
    var projects: [String]
    var skillCategories: [SkillCategory]
    var relevance: [String: RelevanceStats]
    var gaps: [String]
    var rationale: String

    private enum CodingKeys: String, CodingKey {
        case summary, selections, projects, skillCategories, relevance, gaps, rationale
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        selections = try container.decode([TailorSelection].self, forKey: .selections)
        projects = try container.decodeIfPresent([String].self, forKey: .projects) ?? []
        skillCategories =
            try container.decodeIfPresent([SkillCategory].self, forKey: .skillCategories) ?? []
        // Absent decodes as empty so a missing block fails validation with
        // a repairable reason, never a bare decode error.
        relevance =
            try container.decodeIfPresent([String: RelevanceStats].self, forKey: .relevance) ?? [:]
        gaps = try container.decode([String].self, forKey: .gaps)
        rationale = try container.decode(String.self, forKey: .rationale)
    }

    init(
        json: Data,
        validAchievementIDs: Set<String>,
        validProjectIDs: Set<String> = [],
        tagNamesByID: [String: [String]] = [:]
    ) throws {
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
        let unjudged = selectedIDs.filter { relevance[$0] == nil }
        guard unjudged.isEmpty else {
            throw TailorValidationFailure(
                reason: "relevance is missing for selected ids: \(unjudged.joined(separator: ", ")). Judge every selected achievement and project on all four criteria, 0–5."
            )
        }
        let unselected = relevance.keys.filter { !Set(selectedIDs).contains($0) }.sorted()
        guard unselected.isEmpty else {
            throw TailorValidationFailure(
                reason: "relevance judges ids that were not selected: \(unselected.joined(separator: ", ")). Judge only the ids in `selections` and `projects`."
            )
        }
        let misscored = relevance.filter { !$0.value.isOnScale }.keys.sorted()
        guard misscored.isEmpty else {
            throw TailorValidationFailure(
                reason: "relevance scores out of range for: \(misscored.joined(separator: ", ")). Every criterion score is an integer from 0 to 5."
            )
        }
    }
}

struct RelevanceStats: Equatable, Sendable, Decodable {
    var tech: Int
    var domain: Int
    var seniority: Int
    var impact: Int

    var overall: Double {
        Double(tech + domain + seniority + impact) / 4
    }

    var isOnScale: Bool {
        [tech, domain, seniority, impact].allSatisfy { (0...5).contains($0) }
    }
}

struct TailorSelection: Equatable, Sendable, Decodable {
    var achievementID: String
    var bullet: String
}

struct SkillCategory: Equatable, Sendable, Decodable {
    var name: String
    var skills: [String]

    init(name: String, skills: [String]) {
        self.name = name
        self.skills = skills
    }
}
