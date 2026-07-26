import Foundation
import SwiftData

// The app's versioned schemas (decisions/0011). Versioning began at the first
// destructive change — dropping `Achievement.tech` — exactly as PipelineBoard
// decisions/0001 recorded it would. V1 is a frozen, verbatim copy of the
// schema as it stood the day before that change: stored attributes and
// relationships only (computed conveniences live on the live classes). Shared
// value types (ContactInfo, FitMetrics, GroundedRemark, MockTask, Segment and
// the raw-value enums) are not versioned — they are storage-stable Codable
// values.
//
// Entity names come from the unqualified class names, so the nested V1
// classes address the same on-disk entities as the live top-level classes
// (the Apple staged-migration pattern).

enum LadderSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Profile.self, Role.self, Achievement.self, SkillTag.self,
            Education.self, Project.self, Application.self,
            Stage.self, DismissedEvent.self, Transcript.self, Debrief.self,
            DebriefQuestion.self, PrepPack.self, PrepTalkingPoint.self,
            JourneyNarrative.self,
        ]
    }

    @Model
    final class Profile {
        var name: String
        var headline: String
        var contact: ContactInfo
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Role.profile)
        var roles: [Role]

        @Relationship(deleteRule: .cascade, inverse: \SkillTag.profile)
        var skills: [SkillTag]

        @Relationship(deleteRule: .cascade, inverse: \Education.profile)
        var education: [Education] = []

        @Relationship(deleteRule: .cascade, inverse: \Project.profile)
        var projects: [Project] = []

        var interests: [String] = []

        init(name: String, headline: String, contact: ContactInfo = ContactInfo(), updatedAt: Date = .now) {
            self.name = name
            self.headline = headline
            self.contact = contact
            self.updatedAt = updatedAt
            self.roles = []
            self.skills = []
            self.education = []
            self.projects = []
            self.interests = []
        }
    }

    @Model
    final class Role {
        var company: String
        var title: String
        var start: Date
        var end: Date?
        var location: String?
        var industry: String?
        var profile: Profile?

        @Relationship(deleteRule: .cascade, inverse: \Achievement.role)
        var achievements: [Achievement]

        init(company: String, title: String, start: Date, end: Date? = nil) {
            self.company = company
            self.title = title
            self.start = start
            self.end = end
            self.achievements = []
        }
    }

    @Model
    final class Education {
        var institution: String
        var qualification: String
        var start: Date
        var end: Date?
        var detail: String
        var profile: Profile?

        init(institution: String, qualification: String, start: Date, end: Date? = nil, detail: String = "") {
            self.institution = institution
            self.qualification = qualification
            self.start = start
            self.end = end
            self.detail = detail
        }
    }

    @Model
    final class Project {
        var name: String
        var link: String
        var summary: String
        var details: String = ""
        var sortIndex: Int
        var profile: Profile?

        @Relationship
        var skills: [SkillTag]

        init(name: String, link: String = "", summary: String = "", details: String = "", sortIndex: Int = 0) {
            self.name = name
            self.link = link
            self.summary = summary
            self.details = details
            self.sortIndex = sortIndex
            self.skills = []
        }
    }

    @Model
    final class Achievement {
        var title: String?
        var text: String
        var impactMetric: String?
        /// The reason V1 exists: the last schema that stored `tech`.
        var tech: [String]
        var strengthNotes: String?
        var sortIndex: Int
        var role: Role?

        @Relationship
        var skills: [SkillTag]

        init(text: String, tech: [String] = [], sortIndex: Int = 0) {
            self.title = nil
            self.text = text
            self.impactMetric = nil
            self.tech = tech
            self.strengthNotes = nil
            self.sortIndex = sortIndex
            self.skills = []
        }
    }

    @Model
    final class SkillTag {
        var name: String
        var profile: Profile?

        @Relationship(inverse: \Achievement.skills)
        var achievements: [Achievement]

        @Relationship(inverse: \Project.skills)
        var projects: [Project]

        init(name: String) {
            self.name = name
            self.achievements = []
            self.projects = []
        }
    }

    @Model
    final class Application {
        var company: String
        var roleTitle: String
        var jobDescription: String
        var source: String?
        var status: ApplicationStatus
        var appliedAt: Date?
        var cvSnapshot: Data?
        var cvSelectionRationale: String?
        var fitMetrics: FitMetrics? = nil
        var createdAt: Date
        var notes: String = ""

        @Relationship(deleteRule: .cascade, inverse: \Stage.application)
        var stages: [Stage]

        @Relationship(deleteRule: .cascade, inverse: \JourneyNarrative.application)
        var journeyNarrative: JourneyNarrative?

        init(company: String, roleTitle: String, jobDescription: String, status: ApplicationStatus, createdAt: Date = .now) {
            self.company = company
            self.roleTitle = roleTitle
            self.jobDescription = jobDescription
            self.status = status
            self.createdAt = createdAt
            self.stages = []
        }
    }

    @Model
    final class Stage {
        var kindRaw: String
        var scheduledAt: Date?
        var calendarEventID: String?
        var meetingURL: URL?
        var prepContext: String
        var outcome: StageOutcome
        var heardBackAt: Date?
        var sortIndex: Int
        var application: Application?

        @Relationship(deleteRule: .cascade, inverse: \Transcript.stage)
        var transcript: Transcript?

        @Relationship(deleteRule: .cascade, inverse: \Debrief.stage)
        var debrief: Debrief?

        @Relationship(deleteRule: .cascade, inverse: \PrepPack.stage)
        var prepPack: PrepPack?

        init(kindRaw: String, prepContext: String = "", outcome: StageOutcome = .pending, sortIndex: Int = 0) {
            self.kindRaw = kindRaw
            self.prepContext = prepContext
            self.outcome = outcome
            self.sortIndex = sortIndex
        }
    }

    @Model
    final class DismissedEvent {
        var calendarEventID: String
        var dismissedAt: Date

        init(calendarEventID: String, dismissedAt: Date = .now) {
            self.calendarEventID = calendarEventID
            self.dismissedAt = dismissedAt
        }
    }

    @Model
    final class Transcript {
        var recordedAt: Date
        var durationSec: Int
        var sourceApp: String?
        var notesSummary: String?
        var segments: [Segment]
        var stage: Stage?

        init(recordedAt: Date, durationSec: Int = 0, segments: [Segment] = []) {
            self.recordedAt = recordedAt
            self.durationSec = durationSec
            self.segments = segments
        }
    }

    @Model
    final class Debrief {
        var generatedAt: Date
        var themes: [GroundedRemark]
        var signals: [GroundedRemark]
        var drills: [String]
        var stage: Stage?

        @Relationship(deleteRule: .cascade, inverse: \DebriefQuestion.debrief)
        var questions: [DebriefQuestion]

        init(generatedAt: Date) {
            self.generatedAt = generatedAt
            self.themes = []
            self.signals = []
            self.drills = []
            self.questions = []
        }
    }

    @Model
    final class DebriefQuestion {
        var question: String
        var answerSummary: String
        var quality: AnswerQuality
        var quote: String
        var sortIndex: Int
        var debrief: Debrief?
        var missedAmmo: [Achievement]

        init(question: String, answerSummary: String, quality: AnswerQuality, quote: String, sortIndex: Int = 0) {
            self.question = question
            self.answerSummary = answerSummary
            self.quality = quality
            self.quote = quote
            self.sortIndex = sortIndex
            self.missedAmmo = []
        }
    }

    @Model
    final class PrepPack {
        var generatedAt: Date
        var likelyQuestions: [String]
        var companyBrief: String?
        var mockTasks: [MockTask]
        var stage: Stage?

        @Relationship(deleteRule: .cascade, inverse: \PrepTalkingPoint.prepPack)
        var talkingPoints: [PrepTalkingPoint]

        init(generatedAt: Date) {
            self.generatedAt = generatedAt
            self.likelyQuestions = []
            self.companyBrief = nil
            self.mockTasks = []
            self.talkingPoints = []
        }
    }

    @Model
    final class PrepTalkingPoint {
        var text: String
        var sortIndex: Int
        var prepPack: PrepPack?
        var achievements: [Achievement]

        init(text: String, sortIndex: Int = 0) {
            self.text = text
            self.sortIndex = sortIndex
            self.achievements = []
        }
    }

    @Model
    final class JourneyNarrative {
        var text: String
        var generatedAt: Date
        var application: Application?

        init(text: String, generatedAt: Date) {
            self.text = text
            self.generatedAt = generatedAt
        }
    }
}

/// The live schema: the top-level model classes as they stand. `tech` is
/// gone from Achievement; `aliases` arrives on SkillTag.
enum LadderSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Profile.self, Role.self, Achievement.self, SkillTag.self,
            Education.self, Project.self, Application.self,
            Stage.self, DismissedEvent.self, Transcript.self, Debrief.self,
            DebriefQuestion.self, PrepPack.self, PrepTalkingPoint.self,
            JourneyNarrative.self,
        ]
    }
}

enum LadderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LadderSchemaV1.self, LadderSchemaV2.self]
    }

    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// [PROFILE-24]: fold each achievement's tech strings into the shared
    /// Tag pool by the [PROFILE-8] rule — trimmed, case-insensitive, first
    /// casing wins — while both `tech` and `skills` still exist (V1), then
    /// let the transition to V2 drop the attribute.
    private static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: LadderSchemaV1.self,
        toVersion: LadderSchemaV2.self,
        willMigrate: { context in
            guard
                let profile = try context.fetch(
                    FetchDescriptor<LadderSchemaV1.Profile>()
                ).first
            else { return }

            func resolvePoolTag(named rawName: String) -> LadderSchemaV1.SkillTag? {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                if let existing = profile.skills.first(where: {
                    $0.name.caseInsensitiveCompare(name) == .orderedSame
                }) {
                    return existing
                }
                let tag = LadderSchemaV1.SkillTag(name: name)
                profile.skills.append(tag)
                return tag
            }

            // Deterministic fold order (sortIndex) so first casing wins
            // reproducibly; orphan achievements (role == nil) fold too.
            let achievements = try context.fetch(
                FetchDescriptor<LadderSchemaV1.Achievement>(
                    sortBy: [SortDescriptor(\.sortIndex)])
            )
            for achievement in achievements {
                for raw in achievement.tech {
                    guard let tag = resolvePoolTag(named: raw) else { continue }
                    if !achievement.skills.contains(where: { $0 === tag }) {
                        achievement.skills.append(tag)
                    }
                }
                achievement.tech = []
            }
            try context.save()
        },
        didMigrate: nil
    )
}
