import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct PrepPackExportTests {
    private func makeStageWithPack(
        in context: ModelContext,
        companyBrief: String? = "Summit Labs is hiring a Platform Engineer to own reliability.",
        mockTasks: [MockTask] = [
            MockTask(
                title: "Design a rate limiter",
                brief: "Sketch a rate limiter for a multi-tenant API.")
        ]
    ) throws -> Stage {
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .active)
        context.insert(application)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        stage.application = application

        let achievement = Achievement(text: "Led incident response for the payments outage")
        context.insert(achievement)
        let pack = PrepPack(
            generatedAt: Date(timeIntervalSince1970: 1_772_300_000),
            likelyQuestions: [
                "Walk me through a production incident you owned end to end.",
                "How would you scale our ingestion pipeline?",
            ],
            companyBrief: companyBrief,
            mockTasks: mockTasks)
        context.insert(pack)
        let point = PrepTalkingPoint(
            text: "Lead with the payments-outage incident command story",
            sortIndex: 0,
            achievements: [achievement])
        context.insert(point)
        point.prepPack = pack
        stage.prepPack = pack
        try context.save()
        return stage
    }

    @Test("[PREP-19] the exported markdown contains every section of the prep pack")
    func exportedMarkdownContainsEverySection() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = try makeStageWithPack(in: context)
        let pack = try #require(stage.prepPack)

        let markdown = PrepPackMarkdown.render(pack, for: stage)

        #expect(markdown.contains("# Prep pack — Summit Labs · Platform Engineer"))
        #expect(markdown.contains("## Company brief"))
        #expect(markdown.contains("Summit Labs is hiring a Platform Engineer to own reliability."))
        #expect(markdown.contains("## Likely questions"))
        #expect(markdown.contains("1. Walk me through a production incident you owned end to end."))
        #expect(markdown.contains("2. How would you scale our ingestion pipeline?"))
        #expect(markdown.contains("## Talking points"))
        #expect(markdown.contains("- Lead with the payments-outage incident command story"))
        #expect(
            markdown.contains("Led incident response for the payments outage"),
            "each talking point carries the text of its mapped Achievements")
        #expect(markdown.contains("## Mock tasks"))
        #expect(markdown.contains("### Design a rate limiter"))
        #expect(markdown.contains("Sketch a rate limiter for a multi-tenant API."))
    }

    @Test("[PREP-19] sections with nothing to say are omitted rather than left as empty headings")
    func emptySectionsAreOmitted() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = try makeStageWithPack(in: context, companyBrief: nil, mockTasks: [])
        let pack = try #require(stage.prepPack)

        let markdown = PrepPackMarkdown.render(pack, for: stage)

        #expect(!markdown.contains("## Company brief"))
        #expect(!markdown.contains("## Mock tasks"))
        #expect(markdown.contains("## Likely questions"), "populated sections still render")
        #expect(markdown.contains("## Talking points"))
    }

    @Test("[PREP-19] the markdown file document writes the rendered text as its bytes")
    func fileDocumentWritesTheRenderedBytes() throws {
        let document = MarkdownFileDocument(text: "# Prep pack — Summit Labs\n")
        let wrapper = document.fileWrapper()
        #expect(wrapper.regularFileContents == Data("# Prep pack — Summit Labs\n".utf8))
    }
}
