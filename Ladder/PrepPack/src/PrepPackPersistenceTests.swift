import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct PrepPackPersistenceTests {
    /// A Stage on an Application plus one Achievement to map from a talking
    /// point.
    private func makeStage(in context: ModelContext) throws -> (Stage, Achievement) {
        let profile = Profile(name: "Alex Climber", headline: "Staff Engineer")
        context.insert(profile)
        let role = Role(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000))
        profile.roles.append(role)
        let achievement = Achievement(text: "Led incident response for the payments outage")
        role.achievements.append(achievement)

        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .active)
        context.insert(application)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        stage.application = application
        try context.save()
        return (stage, achievement)
    }

    private func makePrepPack(
        on stage: Stage, mapped: Achievement, in context: ModelContext
    ) throws -> PrepPack {
        let pack = PrepPack(
            generatedAt: Date(timeIntervalSince1970: 1_772_300_000),
            likelyQuestions: [
                "Walk me through a production incident you owned end to end.",
                "How would you scale our ingestion pipeline?",
            ],
            companyBrief: "Summit Labs is hiring a Platform Engineer to own reliability.",
            mockTasks: [
                MockTask(
                    title: "Design a rate limiter",
                    brief: "Sketch a rate limiter for a multi-tenant API.")
            ])
        context.insert(pack)
        let first = PrepTalkingPoint(
            text: "Lead with the payments-outage incident command story",
            sortIndex: 0,
            achievements: [mapped])
        context.insert(first)
        first.prepPack = pack
        let second = PrepTalkingPoint(
            text: "Ask how the platform team measures reliability today",
            sortIndex: 1)
        context.insert(second)
        second.prepPack = pack
        stage.prepPack = pack
        try context.save()
        return pack
    }

    @Test("[PREP-2] a fully-populated PrepPack round-trips through a store reopen")
    func fullyPopulatedPrepPackRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let (stage, mapped) = try makeStage(in: context)
            _ = try makePrepPack(on: stage, mapped: mapped, in: context)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let pack = try #require(try context.fetch(FetchDescriptor<PrepPack>()).first)
        #expect(pack.generatedAt == Date(timeIntervalSince1970: 1_772_300_000))
        #expect(pack.likelyQuestions == [
            "Walk me through a production incident you owned end to end.",
            "How would you scale our ingestion pipeline?",
        ], "likely questions round-trip field-for-field")
        #expect(pack.companyBrief == "Summit Labs is hiring a Platform Engineer to own reliability.")
        #expect(pack.mockTasks == [
            MockTask(
                title: "Design a rate limiter",
                brief: "Sketch a rate limiter for a multi-tenant API.")
        ], "mock tasks round-trip title and brief")
        #expect(pack.stage?.kind == .technical)

        let points = pack.orderedTalkingPoints
        try #require(points.count == 2)
        #expect(points[0].text == "Lead with the payments-outage incident command story")
        #expect(points[0].sortIndex == 0)
        #expect(points[0].achievements.map(\.text) == [
            "Led incident response for the payments outage"
        ], "mapped achievements link to the persisted Achievement")
        #expect(points[1].text == "Ask how the platform team measures reliability today")
        #expect(points[1].achievements.isEmpty)
    }

    @Test("[PREP-3] deleting a Stage deletes its prep pack with it")
    func deletingStageCascadesToPrepPack() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let (stage, mapped) = try makeStage(in: context)
        _ = try makePrepPack(on: stage, mapped: mapped, in: context)

        context.delete(stage)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PrepPack>()).isEmpty, "no orphaned PrepPack survives")
        #expect(
            try context.fetch(FetchDescriptor<PrepTalkingPoint>()).isEmpty,
            "no orphaned talking-point rows survive")
        #expect(
            try context.fetch(FetchDescriptor<Achievement>()).count == 1,
            "the mapped-achievement relationship never cascades toward the Profile")
    }

    @Test("[PREP-3] deleting a mapped Achievement leaves no dangling talking-point link")
    func deletingAchievementDropsItFromTalkingPoints() throws {
        // The other direction of the relationship's integrity
        // (decisions/0001): the canon is deletable without the pack holding
        // a dangling reference.
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let (stage, mapped) = try makeStage(in: context)
        _ = try makePrepPack(on: stage, mapped: mapped, in: context)

        context.delete(mapped)
        try context.save()

        let pack = try #require(try context.fetch(FetchDescriptor<PrepPack>()).first)
        #expect(
            pack.orderedTalkingPoints.first?.achievements.isEmpty == true,
            "the deleted Achievement drops out of the talking point")
    }
}
