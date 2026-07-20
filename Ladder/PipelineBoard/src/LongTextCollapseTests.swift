import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// The docs/adr/0003 collapsed-content pattern on this slice's long-text
/// fields: collapse decision, windows, and confirmed removes. Row and dialog
/// chrome are on the visual-verify list.
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

        // Render-smoke of the collapsed detail: row chrome is visual-verify.
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
        // The window renders the text; its read-only chrome is visual-verify.
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

        // Autosave went through the store seams — a fresh context sees it.
        let fresh = ModelContext(store.container)
        let applications = try fresh.fetch(FetchDescriptor<Application>())
        #expect(applications.first?.notes == "first impression, updated after the call")
    }

    @Test("[PIPEBOARD-33] removing a long-text field's content requires confirmation before clearing it")
    func confirmedRemovesClearThroughTheStore() throws {
        // The dialog itself is chrome (visual-verify); the confirmed action
        // clears through the store, leaving every other field untouched.
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

        // Cleared through the store — a fresh context sees empty values.
        let fresh = ModelContext(store.container)
        let applications = try fresh.fetch(FetchDescriptor<Application>())
        #expect(applications.first?.jobDescription.isEmpty == true)
        #expect(applications.first?.notes.isEmpty == true)
    }
}
