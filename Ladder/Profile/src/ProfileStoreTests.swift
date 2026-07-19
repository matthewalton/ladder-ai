import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct ProfileStoreTests {
    private func makeStore() throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        return store
    }

    @Test("[PROFILE-2] launching with no Profile shows the create-profile empty state")
    func emptyStorePresentsCreateProfile() throws {
        let store = try makeStore()
        #expect(store.profile == nil)
        #expect(store.presentation == .createProfile)
    }

    @Test("[PROFILE-3] the create action creates the single Profile with the entered name and headline")
    func createProfileStoresNameAndHeadline() throws {
        let store = try makeStore()
        let created = try store.createProfile(name: "  Alex Climber  ", headline: "Staff Engineer")
        #expect(created.name == "Alex Climber", "name is trimmed (SPEC.md [PROFILE-3] body)")
        #expect(created.headline == "Staff Engineer")
        #expect(created.roles.isEmpty)
        #expect(created.skills.isEmpty)
        #expect(store.profile === created)
    }

    @Test("[PROFILE-4] the store rejects creating a second Profile")
    func secondCreateThrows() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")

        #expect(throws: ProfileStoreError.profileAlreadyExists) {
            try store.createProfile(name: "Somebody Else", headline: "")
        }

        let count = try ModelContext(container).fetchCount(FetchDescriptor<Profile>())
        #expect(count == 1)
    }

    @Test("[PROFILE-6] deleting a role also deletes its achievements")
    func deleteRoleCascadesToAchievements() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        let profile = try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let achievement = try store.addAchievement(to: role, text: "Cut build times")

        // SkillTags are shared across the Profile, so the tag must survive
        // the cascade.
        let tag = SkillTag(name: "Swift")
        profile.skills.append(tag)
        achievement.skills.append(tag)

        try store.deleteRole(role)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Role>()) == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Achievement>()) == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SkillTag>()) == 1)
    }

    @Test("[PROFILE-8] tagging two achievements with the same skill name yields one shared SkillTag")
    func skillNamesDeduplicate() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let first = try store.addAchievement(to: role, text: "Cut build times")
        let second = try store.addAchievement(to: role, text: "Shipped sync engine")

        // The surviving tag keeps the name as first entered.
        let tag = try store.tag(first, skillNamed: "Swift")
        let reused = try store.tag(second, skillNamed: "  swift ")

        #expect(tag === reused)
        #expect(tag.name == "Swift")
        #expect(first.skills.map(\.name) == ["Swift"])
        #expect(second.skills.map(\.name) == ["Swift"])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SkillTag>()) == 1)
    }

    @Test("[PROFILE-10] a Profile with no roles shows the add-first-role empty state")
    func profileWithoutRolesPresentsAddFirstRole() throws {
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        #expect(store.presentation == .addFirstRole)

        try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        #expect(store.presentation == .editor)
    }
}
