import Foundation

/// `achievements` is the ordered list result validation resolves talking-point
/// indices against — index i in the payload is `achievements[i]`
/// (decisions/0001).
@MainActor
struct PrepPackPayload {
    let json: String
    let achievements: [Achievement]

    /// The debriefs of the Application's Stages ordered strictly before the
    /// prepped Stage — a later stage's debrief, or the prepped stage's own,
    /// is never prior ([PREP-8]).
    static func priorDebriefs(for stage: Stage) -> [Debrief] {
        (stage.application?.orderedStages ?? [])
            .filter { $0.sortIndex < stage.sortIndex }
            .compactMap(\.debrief)
    }

    init(stage: Stage, priorDebriefs: [Debrief], profile: Profile?) throws {
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
            stage: PayloadStage(
                kind: stage.kind.rawValue,
                prepContext: stage.prepContext,
                mockTasksWanted: stage.kind.isTechnicalType
            ),
            application: PayloadApplication(
                company: stage.application?.company ?? "",
                roleTitle: stage.application?.roleTitle ?? "",
                jobDescription: stage.application?.jobDescription ?? ""
            ),
            priorDebriefs: priorDebriefs.map { debrief in
                PayloadDebrief(
                    stageKind: debrief.stage?.kind.rawValue ?? "",
                    questions: debrief.orderedQuestions.map {
                        PayloadDebriefQuestion(
                            question: $0.question,
                            answerSummary: $0.answerSummary,
                            quality: $0.quality.rawValue
                        )
                    },
                    themes: debrief.themes.map(\.text),
                    signals: debrief.signals.map(\.text),
                    drills: debrief.drills
                )
            },
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
    var priorDebriefs: [PayloadDebrief]
    var achievements: [PayloadAchievement]
}

private struct PayloadStage: Encodable {
    var kind: String
    var prepContext: String
    var mockTasksWanted: Bool
}

private struct PayloadApplication: Encodable {
    var company: String
    var roleTitle: String
    var jobDescription: String
}

private struct PayloadDebrief: Encodable {
    var stageKind: String
    var questions: [PayloadDebriefQuestion]
    var themes: [String]
    var signals: [String]
    var drills: [String]
}

private struct PayloadDebriefQuestion: Encodable {
    var question: String
    var answerSummary: String
    var quality: String
}

private struct PayloadAchievement: Encodable {
    var index: Int
    var text: String
    var impactMetric: String?
    var tech: [String]
    var skills: [String]
    var strengthNotes: String?
}
