import Foundation

/// `achievements` is the ordered list result validation resolves missed-ammo
/// indices against — index i in the payload is `achievements[i]`
/// (decisions/0001).
@MainActor
struct DebriefPayload {
    let json: String
    let achievements: [Achievement]

    init(stage: Stage, notesOverview: String, profile: Profile?) throws {
        // Roles newest-first, achievements in sort order — the TailorPayload
        // ordering; the JSON must be deterministic.
        let orderedRoles = (profile?.roles ?? []).sorted {
            ($0.start, $1.company) > ($1.start, $0.company)
        }
        var ordered: [Achievement] = []
        var payloadAchievements: [PayloadAchievement] = []
        for role in orderedRoles {
            for achievement in role.orderedAchievements {
                payloadAchievements.append(
                    PayloadAchievement(
                        index: ordered.count,
                        text: achievement.text,
                        impactMetric: achievement.impactMetric,
                        tech: achievement.tech,
                        skills: achievement.skills.map(\.name).sorted(),
                        strengthNotes: achievement.strengthNotes
                    ))
                ordered.append(achievement)
            }
        }
        let body = PayloadBody(
            stage: PayloadStage(kind: stage.kind.rawValue, prepContext: stage.prepContext),
            application: PayloadApplication(
                company: stage.application?.company ?? "",
                roleTitle: stage.application?.roleTitle ?? "",
                jobDescription: stage.application?.jobDescription ?? ""
            ),
            notesOverview: notesOverview,
            achievements: payloadAchievements
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        json = String(decoding: try encoder.encode(body), as: UTF8.self)
        achievements = ordered
    }
}

private struct PayloadBody: Encodable {
    var stage: PayloadStage
    var application: PayloadApplication
    var notesOverview: String
    var achievements: [PayloadAchievement]
}

private struct PayloadStage: Encodable {
    var kind: String
    var prepContext: String
}

private struct PayloadApplication: Encodable {
    var company: String
    var roleTitle: String
    var jobDescription: String
}

private struct PayloadAchievement: Encodable {
    var index: Int
    var text: String
    var impactMetric: String?
    var tech: [String]
    var skills: [String]
    var strengthNotes: String?
}
