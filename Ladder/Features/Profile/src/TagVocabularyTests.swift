import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct TagVocabularyTests {
    @Test("[PROFILE-27] recording an Alias that matches an existing primary name or alias is refused")
    func collidingAliasIsRefused() throws {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let achievement = try store.addAchievement(to: role, text: "Ran the cluster")
        let swift = try store.tag(achievement, skillNamed: "Swift")
        let kubernetes = try store.tag(achievement, skillNamed: "Kubernetes")
        try store.recordAlias("k8s", on: kubernetes)

        #expect(throws: ProfileStoreError.aliasAlreadyInUse) {
            try store.recordAlias(" SWIFT ", on: kubernetes)
        }
        #expect(throws: ProfileStoreError.aliasAlreadyInUse) {
            try store.recordAlias("K8S", on: swift)
        }
        #expect(throws: ProfileStoreError.aliasAlreadyInUse) {
            try store.recordAlias("kubernetes", on: kubernetes)
        }

        #expect(swift.aliases == [], "the pool is unchanged after a refusal")
        #expect(kubernetes.aliases == ["k8s"])
    }

    @Test("[PROFILE-40] removing an Alias from a Tag persists across a store reopen")
    func removedAliasPersists() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let achievement = try store.addAchievement(to: role, text: "Ran the cluster")
            let kubernetes = try store.tag(achievement, skillNamed: "Kubernetes")
            try store.recordAlias("k8s", on: kubernetes)
            try store.removeAlias("k8s", from: kubernetes)
            #expect(kubernetes.aliases == [])
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        let kubernetes = try #require(profile.skills.first { $0.name == "Kubernetes" })
        #expect(kubernetes.aliases == [], "the removal survived the reopen")
        #expect(kubernetes.achievements.count == 1, "the Tag and its links are untouched")

        let achievement = try #require(kubernetes.achievements.first)
        let minted = try reopened.tag(achievement, skillNamed: "k8s")
        #expect(minted.name == "k8s")
        #expect(minted !== kubernetes)
    }

    @Test("[PROFILE-28] tagging a point with a name matching a Tag's Alias links that Tag")
    func taggingByAliasLinksTheTag() throws {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let achievement = try store.addAchievement(to: role, text: "Ran the cluster")
        let kubernetes = try store.tag(achievement, skillNamed: "Kubernetes")
        try store.recordAlias("k8s", on: kubernetes)

        let second = try store.addAchievement(to: role, text: "Scaled the fleet")
        let resolved = try store.tag(second, skillNamed: " K8S ")
        #expect(resolved === kubernetes, "no new Tag is minted")
        #expect(second.skills.map(\.name) == ["Kubernetes"], "the chip shows the primary name")

        let project = try store.addProject(name: "Homelab")
        let projectResolved = try store.tag(project, skillNamed: "k8s")
        #expect(projectResolved === kubernetes, "the same resolution serves Projects ([PROFILE-21])")

        #expect(store.profile?.skills.count == 1, "the pool still holds one Tag")
    }

    @Test("[PROFILE-29] recasing a Tag's primary name persists across a store reopen")
    func recasePersists() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let achievement = try store.addAchievement(to: role, text: "Shipped the app")
            let ios = try store.tag(achievement, skillNamed: "ios")
            try store.recaseTag(ios, to: "iOS")
            #expect(ios.name == "iOS")
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        let ios = try #require(profile.skills.first)
        #expect(ios.name == "iOS", "the curated casing survived the reopen")
        #expect(ios.achievements.count == 1, "links are untouched — the recase never rewrites them")
    }

    @Test("[PROFILE-30] a Tag rename that changes more than casing is refused")
    func renameBeyondRecaseIsRefused() throws {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "")
        let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let achievement = try store.addAchievement(to: role, text: "Wrote the frontend")
        let js = try store.tag(achievement, skillNamed: "JS")

        #expect(throws: ProfileStoreError.renameBeyondRecase) {
            try store.recaseTag(js, to: "JavaScript")
        }
        #expect(js.name == "JS", "the Tag is unchanged after a refusal")
    }

    @Test("[PROFILE-26] recording an Alias on a Tag persists it lowercase across a store reopen")
    func recordedAliasPersistsLowercase() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let achievement = try store.addAchievement(to: role, text: "Ran the cluster")
            let kubernetes = try store.tag(achievement, skillNamed: "Kubernetes")
            try store.recordAlias(" K8s ", on: kubernetes)
            #expect(kubernetes.aliases == ["k8s"], "recording trims and lowercases")
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        let kubernetes = try #require(profile.skills.first { $0.name == "Kubernetes" })
        #expect(kubernetes.aliases == ["k8s"])
    }
}
