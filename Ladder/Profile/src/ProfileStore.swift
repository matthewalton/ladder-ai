import Foundation
import SwiftData

enum ProfileStoreError: Error, Equatable {
    /// Exactly one Profile may exist.
    case profileAlreadyExists
    case noProfile
    case nameRequired
}

enum ProfilePresentation: Equatable {
    case createProfile
    case addFirstRole
    case editor
}

/// All mutations save immediately — persistence is part of the slice's
/// promise, not a detail.
@MainActor
@Observable
final class ProfileStore {
    /// Exposed so sibling slices can open their own contexts on the same
    /// store.
    let container: ModelContainer
    private let context: ModelContext
    private(set) var profile: Profile?

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    /// The app's schema, one place. `url` nil means the app's default store.
    static func container(at url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Profile.self, Role.self, Achievement.self, SkillTag.self,
            Education.self, Project.self, Application.self,
            Stage.self, DismissedEvent.self, Transcript.self, Debrief.self,
            DebriefQuestion.self, PrepPack.self, PrepTalkingPoint.self,
            JourneyNarrative.self,
        ])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func load() throws {
        profile = try context.fetch(FetchDescriptor<Profile>()).first
    }

    var presentation: ProfilePresentation {
        guard let profile else { return .createProfile }
        return profile.roles.isEmpty ? .addFirstRole : .editor
    }

    // MARK: - Profile

    @discardableResult
    func createProfile(name: String, headline: String) throws -> Profile {
        guard try context.fetchCount(FetchDescriptor<Profile>()) == 0 else {
            throw ProfileStoreError.profileAlreadyExists
        }
        let created = Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            headline: headline
        )
        context.insert(created)
        try context.save()
        profile = created
        return created
    }

    func updateIdentity(name: String, headline: String) throws {
        let profile = try requireProfile()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileStoreError.nameRequired }
        profile.name = trimmed
        profile.headline = headline
        touch(profile)
        try context.save()
    }

    /// Whole-struct assignment — mutating a nested field would not reliably
    /// mark the model changed.
    func updateContact(_ contact: ContactInfo) throws {
        let profile = try requireProfile()
        profile.contact = contact
        touch(profile)
        try context.save()
    }

    // MARK: - Roles

    @discardableResult
    func addRole(company: String, title: String, start: Date, end: Date?) throws -> Role {
        let profile = try requireProfile()
        let role = Role(company: company, title: title, start: start, end: end)
        profile.roles.append(role)
        touch(profile)
        try context.save()
        return role
    }

    func updateRole(_ role: Role, company: String, title: String, start: Date, end: Date?) throws {
        let profile = try requireProfile()
        role.company = company
        role.title = title
        role.start = start
        role.end = end
        touch(profile)
        try context.save()
    }

    func deleteRole(_ role: Role) throws {
        let profile = try requireProfile()
        context.delete(role)
        touch(profile)
        try context.save()
    }

    // MARK: - Achievements

    @discardableResult
    func addAchievement(to role: Role, text: String) throws -> Achievement {
        let profile = try requireProfile()
        let nextIndex = (role.achievements.map(\.sortIndex).max() ?? -1) + 1
        let achievement = Achievement(text: text, sortIndex: nextIndex)
        role.achievements.append(achievement)
        touch(profile)
        try context.save()
        return achievement
    }

    func moveAchievements(in role: Role, from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        var ordered = role.orderedAchievements
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, achievement) in ordered.enumerated() {
            achievement.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    func updateAchievementDetails(
        _ achievement: Achievement,
        impactMetric: String?,
        tech: [String],
        strengthNotes: String?
    ) throws {
        let profile = try requireProfile()
        achievement.impactMetric = impactMetric
        achievement.tech = tech
        achievement.strengthNotes = strengthNotes
        touch(profile)
        try context.save()
    }

    /// Achievement text is user-owned canon — this is the only place it
    /// changes.
    func updateAchievementText(_ achievement: Achievement, to text: String) throws {
        let profile = try requireProfile()
        achievement.text = text
        touch(profile)
        try context.save()
    }

    /// Works for role points and project points; resequences the surviving
    /// siblings so sortIndex stays dense.
    func deleteAchievement(_ achievement: Achievement) throws {
        let profile = try requireProfile()
        let siblings = achievement.role?.orderedAchievements ?? achievement.project?.orderedPoints ?? []
        context.delete(achievement)
        for (index, sibling) in siblings.filter({ $0 !== achievement }).enumerated() {
            sibling.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    // MARK: - Skills

    @discardableResult
    func tag(_ achievement: Achievement, skillNamed rawName: String) throws -> SkillTag {
        let profile = try requireProfile()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag: SkillTag
        if let existing = profile.skills.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            tag = existing
        } else {
            tag = SkillTag(name: name)
            profile.skills.append(tag)
        }
        if !achievement.skills.contains(where: { $0 === tag }) {
            achievement.skills.append(tag)
        }
        touch(profile)
        try context.save()
        return tag
    }

    /// Removes the link only — the Tag itself survives (no orphan pruning,
    /// consistent with role deletion).
    func untag(_ achievement: Achievement, tag: SkillTag) throws {
        let profile = try requireProfile()
        achievement.skills.removeAll { $0 === tag }
        touch(profile)
        try context.save()
    }

    // MARK: - Education

    @discardableResult
    func addEducation(
        institution: String, qualification: String, start: Date, end: Date?, detail: String = ""
    ) throws -> Education {
        let profile = try requireProfile()
        let education = Education(
            institution: institution, qualification: qualification,
            start: start, end: end, detail: detail
        )
        profile.education.append(education)
        touch(profile)
        try context.save()
        return education
    }

    func updateEducation(
        _ education: Education,
        institution: String, qualification: String, start: Date, end: Date?, detail: String
    ) throws {
        let profile = try requireProfile()
        education.institution = institution
        education.qualification = qualification
        education.start = start
        education.end = end
        education.detail = detail
        touch(profile)
        try context.save()
    }

    func deleteEducation(_ education: Education) throws {
        let profile = try requireProfile()
        context.delete(education)
        touch(profile)
        try context.save()
    }

    // MARK: - Projects

    @discardableResult
    func addProject(name: String, link: String = "", summary: String = "") throws -> Project {
        let profile = try requireProfile()
        let nextIndex = (profile.projects.map(\.sortIndex).max() ?? -1) + 1
        let project = Project(name: name, link: link, summary: summary, sortIndex: nextIndex)
        profile.projects.append(project)
        touch(profile)
        try context.save()
        return project
    }

    func updateProject(_ project: Project, name: String, link: String, summary: String) throws {
        let profile = try requireProfile()
        project.name = name
        project.link = link
        project.summary = summary
        touch(profile)
        try context.save()
    }

    func deleteProject(_ project: Project) throws {
        let profile = try requireProfile()
        context.delete(project)
        for (index, remaining) in profile.orderedProjects.filter({ $0 !== project }).enumerated() {
            remaining.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    func moveProjects(from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        var ordered = profile.orderedProjects
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in ordered.enumerated() {
            project.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    /// A point belongs to exactly one parent: project points never get a
    /// role, and `addAchievement(to:)` never sets a project.
    @discardableResult
    func addPoint(to project: Project, text: String) throws -> Achievement {
        let profile = try requireProfile()
        let nextIndex = (project.points.map(\.sortIndex).max() ?? -1) + 1
        let point = Achievement(text: text, sortIndex: nextIndex)
        project.points.append(point)
        touch(profile)
        try context.save()
        return point
    }

    func movePoints(in project: Project, from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        var ordered = project.orderedPoints
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, point) in ordered.enumerated() {
            point.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    // MARK: - Interests

    /// Trimmed; empty and case-insensitive duplicates are ignored.
    func addInterest(_ rawName: String) throws {
        let profile = try requireProfile()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !profile.interests.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) else { return }
        profile.interests.append(name)
        touch(profile)
        try context.save()
    }

    func removeInterest(at index: Int) throws {
        let profile = try requireProfile()
        guard profile.interests.indices.contains(index) else { return }
        profile.interests.remove(at: index)
        touch(profile)
        try context.save()
    }

    func moveInterests(from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        profile.interests.move(fromOffsets: source, toOffset: destination)
        touch(profile)
        try context.save()
    }

    private func requireProfile() throws -> Profile {
        guard let profile else { throw ProfileStoreError.noProfile }
        return profile
    }

    private func touch(_ profile: Profile) {
        profile.updatedAt = .now
    }
}
