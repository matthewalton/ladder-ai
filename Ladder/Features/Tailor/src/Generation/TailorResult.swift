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
    /// The per-point relevance stats, keyed by selected `a…`/`p…` id —
    /// required for every selected point, transient like the whole result
    /// (decisions/0017).
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
        // Absent decodes as empty so a missing block reads as "unjudged
        // selected points" — a validation failure with a repairable reason,
        // never a bare decode error.
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
        // Every selected point is judged, only selected points are judged,
        // and every score sits on the 0–5 scale ([TAILOR-59], [TAILOR-60]).
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

/// The four LLM-judged relevance scores one selected point carries
/// ([TAILOR-59]) — tech/tooling, topic/domain, responsibility/seniority,
/// impact/outcome, each an integer 0–5. Per-point stats only: they never
/// move the Match score (root ADR 0005; decisions/0017).
struct RelevanceStats: Equatable, Sendable, Decodable {
    var tech: Int
    var domain: Int
    var seniority: Int
    var impact: Int

    /// The overall relevance ([TAILOR-61]): the unweighted mean of the four
    /// sub-scores, computed here and never returned by the model — a mean
    /// of four 0–5 integers lands on quarter precision exactly.
    var overall: Double {
        Double(tech + domain + seniority + impact) / 4
    }

    var isOnScale: Bool {
        [tech, domain, seniority, impact].allSatisfy { (0...5).contains($0) }
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
