import Foundation
import SwiftData

/// The Match review confirmation door (root ADR 0005; decisions/0015),
/// shared by every surface that presents the review — the tailor flow and
/// the application detail's Match section (PipelineBoard decisions/0009).
/// Each accepted suggestion applies independently, in the Application's own
/// context so the pool and the Match stay one set of instances. Mint and
/// alias resolve alias-aware at confirm time, where the view of the pool is
/// never stale — the [PROFILE-34]/[PROFILE-35] semantics; a colliding alias
/// is refused like a manual one ([PROFILE-27]) and noted. A resolving
/// suggestion then moves its gap into the matched Tags ([TAILOR-49]).
@MainActor
enum MatchReviewConfirmation {
    /// Applies the review's accepted suggestions and returns the
    /// per-suggestion refusal notes — a colliding alias is skipped, never a
    /// reason to derail the rest ([TAILOR-48]).
    static func apply(_ review: MatchReviewModel, to application: Application) throws -> [String] {
        var notes: [String] = []
        guard
            let context = application.modelContext,
            let match = application.match,
            let profile = try context.fetch(FetchDescriptor<Profile>()).first
        else { return notes }

        for item in review.suggestions where item.isAccepted {
            let landed: SkillTag?
            switch item.proposal.change {
            case .attach:
                // The scan never proposes attach ([TAILOR-30]) — nothing
                // to do if one ever appeared.
                landed = nil
            case .mint(let rawName):
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let existing = resolve(name, in: profile.skills) {
                    landed = existing
                } else {
                    let tag = SkillTag(name: name)
                    profile.skills.append(tag)
                    landed = tag
                }
            case .alias(let rawAlias, let onTagNamed):
                guard let target = resolve(onTagNamed, in: profile.skills) else {
                    notes.append(
                        "No Tag named '\(onTagNamed)' to record the alias on.")
                    continue
                }
                let alias = rawAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !alias.isEmpty else { continue }
                let collides = profile.skills.contains { poolTag in
                    poolTag.name.caseInsensitiveCompare(alias) == .orderedSame
                        || poolTag.aliases.contains(alias)
                }
                guard !collides else {
                    notes.append(
                        "The alias '\(alias)' already resolves in the pool — not recorded.")
                    continue
                }
                target.aliases.append(alias)
                landed = target
            }

            // decisions/0015: the gap leaves, the resolved Tag joins — one
            // reference, and `scannedAt` stays where the scan put it.
            if let landed, let gap = item.proposal.resolves {
                match.vocabularyGaps.removeAll { $0 == gap }
                if !match.matchedTags.contains(where: { $0 === landed }) {
                    match.matchedTags.append(landed)
                }
            }
        }
        try context.save()
        return notes
    }

    /// Case-insensitive across primary names and Aliases — the pool's one
    /// resolution rule (root `CONTEXT.md`: Alias).
    private static func resolve(_ rawName: String, in pool: [SkillTag]) -> SkillTag? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return pool.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
                || $0.aliases.contains(name.lowercased())
        }
    }
}
