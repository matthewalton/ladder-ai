import Foundation
import SwiftData

enum ProfileStoreError: Error, Equatable {
    /// The single-profile invariant: exactly one Profile may exist
    /// (SPEC.md [PROFILE-4], decisions/0002).
    case profileAlreadyExists
    /// Mutations that need a Profile were called before one was created.
    case noProfile
}

/// Which screen the Profile slice presents (SPEC.md [PROFILE-2], [PROFILE-10]).
enum ProfilePresentation: Equatable {
    case createProfile
    case addFirstRole
    case editor
}

/// MVVM-lite store for the Profile slice. All mutations save immediately —
/// persistence is part of the slice's promise, not a detail.
@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext
    private(set) var profile: Profile?

    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    /// The slice's schema, one place. `url` nil means the app's default store.
    static func container(at url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Profile.self, Role.self, Achievement.self, SkillTag.self])
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

    /// Reassigns `sortIndex` to match the dragged order (SPEC.md [PROFILE-7]).
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

    /// The same store pathway as text edits carries impactMetric, tech, and
    /// strengthNotes (SPEC.md [PROFILE-9] body).
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
    /// changes (SPEC.md [PROFILE-9], root CONTEXT.md).
    func updateAchievementText(_ achievement: Achievement, to text: String) throws {
        let profile = try requireProfile()
        achievement.text = text
        touch(profile)
        try context.save()
    }

    // MARK: - Skills

    /// Tags an achievement, reusing the Profile's existing SkillTag when the
    /// name matches case-insensitively after trimming (SPEC.md [PROFILE-8]).
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

    private func requireProfile() throws -> Profile {
        guard let profile else { throw ProfileStoreError.noProfile }
        return profile
    }

    private func touch(_ profile: Profile) {
        profile.updatedAt = .now
    }
}
