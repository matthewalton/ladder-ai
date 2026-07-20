import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct DebriefPersistenceTests {
    /// A Stage on an Application plus one Achievement to link as missed ammo.
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

    private func makeDebrief(on stage: Stage, ammo: Achievement, in context: ModelContext) throws -> Debrief {
        let debrief = Debrief(
            generatedAt: Date(timeIntervalSince1970: 1_772_100_000),
            themes: [
                GroundedRemark(
                    text: "Reliability ran through the whole conversation",
                    quote: "Walked through the incident timeline")
            ],
            signals: [
                GroundedRemark(
                    text: "The interviewer probed Kubernetes depth twice",
                    quote: "asked twice about Kubernetes")
            ],
            drills: ["Rehearse the outage story leading with the incident-command role"]
        )
        context.insert(debrief)
        let first = DebriefQuestion(
            question: "How did you handle the payments outage?",
            answerSummary: "Walked the timeline but never claimed the lead",
            quality: .adequate,
            quote: "Walked through the incident timeline",
            sortIndex: 0,
            missedAmmo: [ammo]
        )
        context.insert(first)
        first.debrief = debrief
        let second = DebriefQuestion(
            question: "How do you keep CI fast?",
            answerSummary: "Concrete numbers on build times",
            quality: .strong,
            quote: "Discussed build times",
            sortIndex: 1
        )
        context.insert(second)
        second.debrief = debrief
        stage.debrief = debrief
        try context.save()
        return debrief
    }

    @Test("[DEBRIEF-2] a fully-populated Debrief round-trips through a store reopen")
    func fullyPopulatedDebriefRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let (stage, ammo) = try makeStage(in: context)
            _ = try makeDebrief(on: stage, ammo: ammo, in: context)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let debrief = try #require(try context.fetch(FetchDescriptor<Debrief>()).first)
        #expect(debrief.generatedAt == Date(timeIntervalSince1970: 1_772_100_000))
        #expect(debrief.themes == [
            GroundedRemark(
                text: "Reliability ran through the whole conversation",
                quote: "Walked through the incident timeline")
        ], "themes round-trip field-for-field")
        #expect(debrief.signals == [
            GroundedRemark(
                text: "The interviewer probed Kubernetes depth twice",
                quote: "asked twice about Kubernetes")
        ], "signals round-trip field-for-field")
        #expect(debrief.drills == ["Rehearse the outage story leading with the incident-command role"])
        #expect(debrief.stage?.kind == .technical)

        let questions = debrief.orderedQuestions
        try #require(questions.count == 2)
        #expect(questions[0].question == "How did you handle the payments outage?")
        #expect(questions[0].answerSummary == "Walked the timeline but never claimed the lead")
        #expect(questions[0].quality == .adequate)
        #expect(questions[0].quote == "Walked through the incident timeline")
        #expect(questions[0].sortIndex == 0)
        #expect(questions[0].missedAmmo.map(\.text) == [
            "Led incident response for the payments outage"
        ], "missed ammo links to the persisted Achievement")
        #expect(questions[1].quality == .strong)
        #expect(questions[1].missedAmmo.isEmpty)
    }

    @Test("[DEBRIEF-3] deleting a Stage deletes its debrief with it")
    func deletingStageCascadesToDebrief() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let (stage, ammo) = try makeStage(in: context)
        _ = try makeDebrief(on: stage, ammo: ammo, in: context)

        context.delete(stage)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Debrief>()).isEmpty, "no orphaned Debrief survives")
        #expect(
            try context.fetch(FetchDescriptor<DebriefQuestion>()).isEmpty,
            "no orphaned question entries survive")
        #expect(
            try context.fetch(FetchDescriptor<Achievement>()).count == 1,
            "the missed-ammo relationship never cascades toward the Profile")
    }

    @Test("[DEBRIEF-3] deleting a linked Achievement leaves no dangling missed ammo")
    func deletingAchievementDropsItFromMissedAmmo() throws {
        // The other direction of the relationship's integrity
        // (decisions/0001): the canon is deletable without the debrief
        // holding a dangling reference.
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let (stage, ammo) = try makeStage(in: context)
        _ = try makeDebrief(on: stage, ammo: ammo, in: context)

        context.delete(ammo)
        try context.save()

        let debrief = try #require(try context.fetch(FetchDescriptor<Debrief>()).first)
        #expect(
            debrief.orderedQuestions.first?.missedAmmo.isEmpty == true,
            "the deleted Achievement drops out of missedAmmo")
    }
}
