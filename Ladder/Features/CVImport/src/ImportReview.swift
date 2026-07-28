import Foundation

@MainActor
@Observable
final class ImportReview {
    let identity: ProposedIdentity
    let roles: [ReviewedRole]
    let education: [ReviewedEducation]
    let projects: [ReviewedProject]
    let interests: [ReviewedInterest]
    let notImportedSections: [NotImportedSection]

    init(proposal: ImportProposal) {
        identity = proposal.identity
        roles = proposal.roles.map(ReviewedRole.init)
        education = proposal.education.map(ReviewedEducation.init)
        projects = proposal.projects.map(ReviewedProject.init)
        interests = proposal.interests.map(ReviewedInterest.init)
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
    let tags: [ReviewedTag]
    var included = true

    init(proposed: ProposedAchievement) {
        self.proposed = proposed
        self.tags = proposed.tags.map(ReviewedTag.init)
    }
}

@MainActor
@Observable
final class ReviewedTag: Identifiable {
    let name: String
    var included = true

    init(name: String) {
        self.name = name
    }
}

@MainActor
@Observable
final class ReviewedEducation: Identifiable {
    let proposed: ProposedEducation
    var included = true

    init(proposed: ProposedEducation) {
        self.proposed = proposed
    }
}

@MainActor
@Observable
final class ReviewedProject: Identifiable {
    let proposed: ProposedProject
    let tags: [ReviewedTag]
    var included = true

    init(proposed: ProposedProject) {
        self.proposed = proposed
        self.tags = proposed.tags.map(ReviewedTag.init)
    }
}

@MainActor
@Observable
final class ReviewedInterest: Identifiable {
    let name: String
    var included = true

    init(name: String) {
        self.name = name
    }
}
