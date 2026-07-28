import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

@MainActor
struct LongTextCollapseTests {
    private func makeStore(
        notes: String = "", jobDescription: String = ""
    ) throws -> (PipelineStore, Application) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(
            Application(
                company: "Summit Labs", roleTitle: "Engineer",
                jobDescription: jobDescription, status: .applied,
                appliedAt: .now, notes: notes))
        try context.save()
        let store = PipelineStore(container: container)
        try store.load()
        return (store, try #require(store.applications.first))
    }

    @Test("[PIPEBOARD-29] a non-empty long-text field collapses to an indicator row when its form appears")
    func nonEmptyFieldCollapses() throws {
        #expect(LongTextField.collapsesAtAppearance("Own platform reliability."))

        let (store, application) = try makeStore(
            notes: "warm intro via Sam", jobDescription: "Own platform reliability.")
        let detail = ImageRenderer(
            content: ApplicationDetailView(store: store, application: application)
                .frame(width: 420, height: 560))
        #expect(detail.nsImage != nil, "the detail renders with both fields collapsed")
    }

    @Test("[PIPEBOARD-30] a long-text field that is empty when its form appears keeps its inline editor")
    func emptyFieldKeepsEditor() {
        #expect(!LongTextField.collapsesAtAppearance(""))
        #expect(
            !LongTextField.collapsesAtAppearance(" \n"),
            "whitespace-only counts as empty — nothing to collapse")
    }

    @Test("[PIPEBOARD-31] opening the job description shows its text in a read-only window")
    func jobDescriptionWindowResolvesReadOnly() throws {
        let (store, application) = try makeStore(jobDescription: "Own platform reliability.")
        let window = JobDescriptionWindow(
            store: store, applicationID: application.persistentModelID)

        #expect(window.resolvedApplication?.jobDescription == "Own platform reliability.")
        #expect(
            JobDescriptionWindow.openAffordance == "View",
            "the window never edits, so the row must not promise Open")
        let image = ImageRenderer(content: window.frame(width: 480, height: 360))
        #expect(image.nsImage != nil)

        try store.deleteApplication(application)
        #expect(window.resolvedApplication == nil, "a deleted Application shows the gone message")
    }

    @Test("[PIPEBOARD-32] opening the notes or the prep context shows the text in an editable window")
    func editableWindowsSaveThroughTheStore() throws {
        let (store, application) = try makeStore(notes: "first impression")
        let notesWindow = NotesEditWindow(
            store: store, applicationID: application.persistentModelID)
        notesWindow.save("first impression, updated after the call")
        #expect(application.notes == "first impression, updated after the call")

        let stage = try store.addStage(
            to: application, kind: .technical, prepContext: "Panel of three")
        let prepWindow = PrepContextEditWindow(
            store: store, stageID: stage.persistentModelID)
        prepWindow.save("Panel of three; whiteboard likely")
        #expect(stage.prepContext == "Panel of three; whiteboard likely")

        let fresh = ModelContext(store.container)
        let applications = try fresh.fetch(FetchDescriptor<Application>())
        #expect(applications.first?.notes == "first impression, updated after the call")

        #expect(NotesEditWindow.openAffordance == "Open")
        #expect(PrepContextEditWindow.openAffordance == "Open")
    }

    @Test("[PIPEBOARD-33] removing a long-text field's content requires confirmation before clearing it")
    func confirmedRemovesClearThroughTheStore() throws {
        let (store, application) = try makeStore(
            notes: "warm intro via Sam", jobDescription: "Own platform reliability.")
        let stage = try store.addStage(
            to: application, kind: .technical, prepContext: "Panel of three")

        try store.clearJobDescription(of: application)
        #expect(application.jobDescription.isEmpty)
        #expect(application.notes == "warm intro via Sam", "clearing one field never touches another")

        try store.clearNotes(of: application)
        #expect(application.notes.isEmpty)

        try store.clearPrepContext(of: stage)
        #expect(stage.prepContext.isEmpty)
        #expect(stage.kind == .technical, "the Stage's other fields stay")

        let fresh = ModelContext(store.container)
        let applications = try fresh.fetch(FetchDescriptor<Application>())
        #expect(applications.first?.jobDescription.isEmpty == true)
        #expect(applications.first?.notes.isEmpty == true)
    }

    @Test("[PIPEBOARD-49] a long-text field's indicator row reports how many words the field holds")
    func indicatorLabelReportsTheWordCount() {
        let english = Locale(identifier: "en_US")
        let posting = String(repeating: "word ", count: 1240)

        #expect(
            LongTextField.indicator(name: "Job description", text: posting, locale: english)
                .label == "Job description — 1,240 words")
        #expect(
            LongTextField.indicator(
                name: "Notes", text: String(repeating: "word ", count: 86), locale: english
            ).label == "Notes — 86 words")
        #expect(
            LongTextField.indicator(
                name: "Prep context", text: String(repeating: "word ", count: 210),
                locale: english
            ).label == "Prep context — 210 words")

        #expect(
            LongTextField.indicator(
                name: "Notes", text: "Senior iOS Engineer\n\nAcme, London", locale: english
            ).label == "Notes — 5 words",
            "the blank line is one run of whitespace, not a word of its own")
        #expect(
            LongTextField.indicator(name: "Notes", text: "  intro\n", locale: english).label
                == "Notes — 1 word",
            "a count of one is singular")

        #expect(
            LongTextField.indicator(
                name: "Job description", text: posting, locale: Locale(identifier: "de_DE")
            ).label == "Job description — 1.240 words",
            "thousands group by the user's locale")
    }

    @Test("[PIPEBOARD-50] a long-text field's indicator row shows the start of the text it holds")
    func indicatorSnippetShowsTheOpening() {
        let posting =
            "Senior iOS Engineer\n\nAcme, London. We are looking for someone to own our design system end to end."
        let snippet = LongTextField.indicator(name: "Job description", text: posting).snippet

        #expect(
            snippet
                == "Senior iOS Engineer Acme, London. We are looking for someone to own our design…")
        #expect(snippet.count == 79, "78 characters, cut back off \"design s\", plus the ellipsis")

        #expect(
            LongTextField.indicator(name: "Notes", text: "  Warm intro\n\tvia Sam  ").snippet
                == "Warm intro via Sam",
            "trimmed, and every run of whitespace collapsed to a single space")

        let eighty = String(String(repeating: "ab ", count: 30).prefix(80))
        #expect(eighty.count == 80)
        #expect(
            LongTextField.indicator(name: "Notes", text: eighty).snippet == eighty,
            "80 characters or fewer once normalised shows whole, with no ellipsis")

        let eightyOne = eighty + "c"
        #expect(
            LongTextField.indicator(name: "Notes", text: eightyOne).snippet.hasSuffix("…"),
            "one character over the limit truncates")
    }
}
