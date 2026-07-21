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

    @Test("[PROFILE-18] a replace with no Profile on file creates the single Profile with the replacement content")
    func replaceCreatesProfileWhenNoneExists() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        #expect(store.profile == nil)

        try store.replaceProfile(with: ProfileReplacement(
            name: "  Matthew Alton  ",
            headline: "Software Engineer",
            contact: ContactInfo(email: "matt@example.com", phone: "", location: "London", link: ""),
            roles: [ReplacementRole(
                company: "Travelex", title: "Engineer", start: .now, end: nil,
                achievements: [ReplacementPoint(text: "Shipped the Rate Sale feature", skills: ["React"])]
            )],
            interests: ["Cycling"]
        ))

        let profile = try #require(store.profile)
        #expect(profile.name == "Matthew Alton", "name is trimmed, as in [PROFILE-3]")
        #expect(profile.headline == "Software Engineer")
        #expect(store.presentation == .editor)
        #expect(profile.roles.first?.company == "Travelex")
        #expect(profile.roles.first?.orderedAchievements.map(\.text) == ["Shipped the Rate Sale feature"])
        #expect(profile.interests == ["Cycling"])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Profile>()) == 1)

        // The invariant holds through the replace branch too: a second
        // explicit create is still rejected ([PROFILE-4]).
        #expect(throws: ProfileStoreError.profileAlreadyExists) {
            try store.createProfile(name: "Somebody Else", headline: "")
        }
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

    @Test("[PROFILE-10] a Profile with no roles goes straight to the editor")
    func profileWithoutRolesPresentsEditor() throws {
        // The empty Experience section carries the add-first-role copy; there
        // is no separate presentation state for it.
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        #expect(store.presentation == .editor)

        try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        #expect(store.presentation == .editor)
    }

    @Test("[PROFILE-13] identity and contact edits land on the Profile")
    func identityAndContactEditsApply() throws {
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "Engineer")

        try store.updateIdentity(name: "  Alexandra Climber ", headline: "Staff Engineer")
        #expect(store.profile?.name == "Alexandra Climber", "name is trimmed")
        #expect(store.profile?.headline == "Staff Engineer")

        #expect(throws: ProfileStoreError.nameRequired) {
            try store.updateIdentity(name: "   ", headline: "x")
        }
        #expect(store.profile?.name == "Alexandra Climber")

        let contact = ContactInfo(email: "alex@example.com", phone: "", location: "London", link: "")
        try store.updateContact(contact)
        #expect(store.profile?.contact == contact)
    }

    @Test("updating a role rewrites company, title, and dates")
    func updateRoleAppliesFields() throws {
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)

        let start = Date(timeIntervalSince1970: 1_400_000_000)
        let end = Date(timeIntervalSince1970: 1_500_000_000)
        try store.updateRole(role, company: "Initech", title: "Senior Engineer", start: start, end: end)
        #expect(role.company == "Initech")
        #expect(role.title == "Senior Engineer")
        #expect(role.start == start)
        #expect(role.end == end)
    }

    @Test("[PROFILE-15] deleting a point keeps the surviving siblings' order dense")
    func deleteAchievementResequencesSiblings() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        try store.addAchievement(to: role, text: "First")
        let second = try store.addAchievement(to: role, text: "Second")
        try store.addAchievement(to: role, text: "Third")

        try store.deleteAchievement(second)

        #expect(role.orderedAchievements.map(\.text) == ["First", "Third"])
        #expect(role.orderedAchievements.map(\.sortIndex) == [0, 1])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Achievement>()) == 2)
    }

    @Test("[PROFILE-16] untagging removes the link but never the Tag")
    func untagLeavesTagAndOtherLinksIntact() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let first = try store.addAchievement(to: role, text: "Cut build times")
        let second = try store.addAchievement(to: role, text: "Shipped sync engine")
        let tag = try store.tag(first, skillNamed: "Swift")
        try store.tag(second, skillNamed: "Swift")

        try store.untag(first, tag: tag)

        #expect(first.skills.isEmpty)
        #expect(second.skills.map(\.name) == ["Swift"])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SkillTag>()) == 1)
    }

    @Test("education entries can be added, updated, and deleted")
    func educationCRUD() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        let profile = try store.createProfile(name: "Alex Climber", headline: "")

        let start = Date(timeIntervalSince1970: 1_100_000_000)
        let education = try store.addEducation(
            institution: "University of Example", qualification: "BSc CS", start: start, end: nil
        )
        #expect(profile.education.count == 1)

        let end = Date(timeIntervalSince1970: 1_200_000_000)
        try store.updateEducation(
            education,
            institution: "University of Example", qualification: "MEng CS",
            start: start, end: end, detail: "First-class"
        )
        #expect(education.qualification == "MEng CS")
        #expect(education.end == end)
        #expect(education.detail == "First-class")

        try store.deleteEducation(education)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Education>()) == 0)
    }

    @Test("[PROFILE-11] deleting a Project deletes its points; shared Tags survive")
    func deleteProjectCascadesToPoints() throws {
        let container = try ProfileStore.container(inMemory: true)
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let project = try store.addProject(name: "Trail Mapper")
        let point = try store.addPoint(to: project, text: "Built tile caching")
        try store.tag(point, skillNamed: "Swift")

        try store.deleteProject(project)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Project>()) == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Achievement>()) == 0)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SkillTag>()) == 1)
    }

    @Test("[PROFILE-12] a point belongs to exactly one parent")
    func pointsHaveExactlyOneParent() throws {
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let project = try store.addProject(name: "Trail Mapper")

        let rolePoint = try store.addAchievement(to: role, text: "Cut build times")
        let projectPoint = try store.addPoint(to: project, text: "Built tile caching")

        #expect(rolePoint.role === role)
        #expect(rolePoint.project == nil)
        #expect(projectPoint.project === project)
        #expect(projectPoint.role == nil)
    }

    @Test("[PROFILE-7] reordering a project's points persists the new order")
    func movePointsReordersWithinProject() throws {
        let store = try makeStore()
        try store.createProfile(name: "Alex Climber", headline: "")
        let project = try store.addProject(name: "Trail Mapper")
        try store.addPoint(to: project, text: "First")
        try store.addPoint(to: project, text: "Second")
        try store.addPoint(to: project, text: "Third")

        try store.movePoints(in: project, from: IndexSet(integer: 0), to: 3)
        #expect(project.orderedPoints.map(\.text) == ["Second", "Third", "First"])
    }

    @Test("projects keep a dense manual order through add, move, and delete")
    func projectOrdering() throws {
        let store = try makeStore()
        let profile = try #require(try store.createProfile(name: "Alex Climber", headline: ""))
        let first = try store.addProject(name: "First")
        let second = try store.addProject(name: "Second")
        let third = try store.addProject(name: "Third")
        #expect(profile.orderedProjects.map(\.name) == ["First", "Second", "Third"])

        try store.moveProjects(from: IndexSet(integer: 2), to: 0)
        #expect(profile.orderedProjects.map(\.name) == ["Third", "First", "Second"])

        try store.deleteProject(first)
        #expect(profile.orderedProjects.map(\.name) == ["Third", "Second"])
        #expect(profile.orderedProjects.map(\.sortIndex) == [0, 1])
        _ = second
    }

    @Test("[PROFILE-14] interests keep entered order and dedupe case-insensitively")
    func interestsOrderAndDedupe() throws {
        let store = try makeStore()
        let profile = try store.createProfile(name: "Alex Climber", headline: "")

        try store.addInterest("climbing")
        try store.addInterest("  trail running ")
        try store.addInterest("Climbing")  // duplicate, ignored
        try store.addInterest("   ")  // empty, ignored
        #expect(profile.interests == ["climbing", "trail running"])

        try store.moveInterests(from: IndexSet(integer: 1), to: 0)
        #expect(profile.interests == ["trail running", "climbing"])

        try store.removeInterest(at: 0)
        #expect(profile.interests == ["climbing"])
    }
}
