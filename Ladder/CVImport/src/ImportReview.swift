import Foundation

/// The review (slice CONTEXT.md): the mandatory per-item confirmation step
/// between proposal and merge. Every proposed item enters as included
/// ([CVIMPORT-4]) — the review screen is the dedup (decisions/0003).
@MainActor
@Observable
final class ImportReview {
    let roles: [ReviewedRole]
    let notImportedSections: [NotImportedSection]

    init(proposal: ImportProposal) {
        roles = proposal.roles.map(ReviewedRole.init)
        notImportedSections = proposal.notImportedSections
    }
}

@MainActor
@Observable
final class ReviewedRole: Identifiable {
    let proposed: ProposedRole
    let achievements: [ReviewedAchievement]
    var included = true

    init(proposed: ProposedRole) {
        self.proposed = proposed
        self.achievements = proposed.achievements.map(ReviewedAchievement.init)
    }
}

@MainActor
@Observable
final class ReviewedAchievement: Identifiable {
    let proposed: ProposedAchievement
    let skills: [ReviewedSkill]
    var included = true

    init(proposed: ProposedAchievement) {
        self.proposed = proposed
        self.skills = proposed.skills.map(ReviewedSkill.init)
    }
}

@MainActor
@Observable
final class ReviewedSkill: Identifiable {
    let name: String
    var included = true

    init(name: String) {
        self.name = name
    }
}
