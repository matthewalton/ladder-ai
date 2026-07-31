import XCTest

/// Launches the real app onto a throwaway store and photographs each screen,
/// so a change can be looked at as the app actually draws it — Lists, controls
/// and window chrome included, none of which `ImageRenderer` can render
/// (LadderTests/SnapshotGallery.swift). Run it with `scripts/snapshots.sh`,
/// which lifts the shots out of the result bundle into `.snapshots/ui/`.
///
/// Two tours: the first run on an empty store, and the seeded walk across the
/// whole flow — board, detail, timeline, stage sheet, generation windows, the
/// tailor run to its fit report — on `-LadderTourSeed` data.
@MainActor
final class ScreenTour: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTourTheApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-LadderScratchStore"]
        app.launch()

        let window = mainWindow(of: app)
        XCTAssertTrue(window.waitForExistence(timeout: 60), "app window never appeared")
        record(window, app, named: "01-create-profile")

        let create = window.buttons["Create Profile"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        type("Alex Climber", into: window.textFields.element(boundBy: 0))
        type("Staff Engineer", into: window.textFields.element(boundBy: 1))
        record(window, app, named: "02-create-profile-filled")

        create.click()
        XCTAssertTrue(create.waitForNonExistence(timeout: 10), "profile editor never opened")
        record(window, app, named: "03-profile-editor")

        window.radioButtons["Applications"].click()
        record(window, app, named: "04-applications-empty")
    }

    func testTourTheSeededApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-LadderScratchStore", "-LadderTourSeed"]
        app.launch()

        let window = mainWindow(of: app)
        XCTAssertTrue(window.waitForExistence(timeout: 60), "app window never appeared")
        XCTAssertTrue(window.staticTexts["Alex Climber"].waitForExistence(timeout: 10))
        record(window, app, named: "10-profile")

        tourPipeline(window, app)
        tourStageSheet(window, app)
        tourJourney(window, app)
        tourTailorFlow(window, app)
        tourJobImport(window, app)
        tourSettings(app)
    }

    private func tourPipeline(_ window: XCUIElement, _ app: XCUIApplication) {
        window.radioButtons["Applications"].click()
        XCTAssertTrue(sidebarRow("Summit Labs", in: window).waitForExistence(timeout: 10))
        record(window, app, named: "11-board")

        let board = window.scrollViews.containing(.staticText, identifier: "DRAFT").firstMatch
        board.scroll(byDeltaX: -700, deltaY: 0)
        board.scroll(byDeltaX: -700, deltaY: 0)
        record(window, app, named: "11b-board-closed-trails")
        board.scroll(byDeltaX: 1500, deltaY: 0)

        sidebarRow("Summit Labs", in: window).click()
        XCTAssertTrue(window.staticTexts["Platform Engineer"].waitForExistence(timeout: 10))
        record(window, app, named: "12-application-detail")

        recordAuxWindow(
            openedBy: window.buttons["Open"].firstMatch,
            headerPrefix: "Notes — ", app: app, named: "12b-notes-window")
        recordAuxWindow(
            openedBy: window.buttons["View"].firstMatch,
            headerPrefix: "Job description — ", app: app, named: "12c-job-description-window")

        window.radioButtons["Timeline"].click()
        XCTAssertTrue(
            window.staticTexts
                .matching(NSPredicate(format: "value CONTAINS 'Technical' OR label CONTAINS 'Technical'"))
                .firstMatch.waitForExistence(timeout: 10))
        record(window, app, named: "13-timeline")
        window.radioButtons["Board"].click()
    }

    private func tourJourney(_ window: XCUIElement, _ app: XCUIApplication) {
        let generateJourney = window.buttons["Generate"].firstMatch
        reveal(generateJourney, in: inspectorScrollView(of: window))
        generateJourney.click()
        XCTAssertTrue(
            window.staticTexts
                .matching(NSPredicate(format: "value CONTAINS 'Forty-one days' OR label CONTAINS 'Forty-one days'"))
                .firstMatch.waitForExistence(timeout: 15),
            "the journey narrative never appeared")
        record(window, app, named: "19-journey")
    }

    private func tourStageSheet(_ window: XCUIElement, _ app: XCUIApplication) {
        let stageRow = window.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Technical'")).firstMatch
        reveal(stageRow, in: inspectorScrollView(of: window))
        stageRow.click()

        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "the stage sheet never opened")
        let generate = sheet.buttons["Generate"].firstMatch
        reveal(generate, in: sheet.scrollViews.firstMatch)
        record(window, app, named: "14-stage-sheet")

        // Two Generate buttons in form order: debrief first, then prep pack —
        // after the debrief lands its button reads Regenerate.
        generate.click()
        let debriefLanded = sheet.staticTexts
            .matching(text(beginning: "Debrief generated"))
            .firstMatch.waitForExistence(timeout: 15)
        if !debriefLanded { record(window, app, named: "99-debug-debrief") }
        XCTAssertTrue(debriefLanded, "the debrief never generated")
        let generatePrep = sheet.buttons["Generate"].firstMatch
        reveal(generatePrep, in: sheet.scrollViews.firstMatch)
        generatePrep.click()
        let prepLanded = sheet.staticTexts
            .matching(text(beginning: "Prep pack generated"))
            .firstMatch.waitForExistence(timeout: 15)
        if !prepLanded { record(window, app, named: "99-debug-prep") }
        XCTAssertTrue(prepLanded, "the prep pack never generated")
        record(window, app, named: "15-stage-sheet-generated")

        // Open buttons in form order: prep context, Granola notes, debrief,
        // prep pack.
        let openButtons = sheet.buttons.matching(identifier: "Open")
        recordAuxWindow(
            openedBy: openButtons.element(boundBy: 2),
            headerPrefix: "Debrief — ", app: app, named: "16-debrief-window")
        recordAuxWindow(
            openedBy: openButtons.element(boundBy: 3),
            headerPrefix: "Prep pack — ", app: app, named: "17-prep-pack-window")
        recordAuxWindow(
            openedBy: openButtons.element(boundBy: 1),
            headerPrefix: "Granola notes — ", app: app, named: "18-granola-notes-window")
        recordAuxWindow(
            openedBy: openButtons.element(boundBy: 0),
            headerPrefix: "Prep context — ", app: app, named: "18b-prep-context-window")

        sheet.buttons["Cancel"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
    }

    private func tourTailorFlow(_ window: XCUIElement, _ app: XCUIApplication) {
        sidebarRow("Alpine Systems", in: window).click()
        let createCV = window.buttons["Create CV"]
        XCTAssertTrue(createCV.waitForExistence(timeout: 10))
        createCV.click()

        let sheet = window.sheets.firstMatch
        let continueButton = sheet.buttons["Continue to tailoring"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 15), "the match review never appeared")
        record(window, app, named: "20-match-review")

        continueButton.click()
        let preview = sheet.buttons["Preview CV…"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15), "the tailor review never appeared")
        record(window, app, named: "21-tailor-review")

        preview.click()
        let export = sheet.buttons["Export CV…"]
        XCTAssertTrue(export.waitForExistence(timeout: 20), "the CV preview never appeared")
        record(window, app, named: "22-cv-preview")

        export.click()
        // The save panel is the sandbox's out-of-process one — it may never
        // surface in the tree, and Escape still reaches it.
        if app.buttons["Save"].waitForExistence(timeout: 15) {
            record(window, app, named: "22b-save-panel")
            app.buttons["Cancel"].firstMatch.click()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }

        let done = sheet.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "the fit report never appeared")
        record(window, app, named: "23-fit-report")
        done.click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
    }

    private func tourJobImport(_ window: XCUIElement, _ app: XCUIApplication) {
        window.buttons["Create application"].firstMatch.click()
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "the job import sheet never opened")
        record(window, app, named: "24-job-import-sheet")
        sheet.buttons["Cancel"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
    }

    private func tourSettings(_ app: XCUIApplication) {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Ladder"].click()
        menuBar.menuBarItems["Ladder"].menuItems["Settings…"].click()
        let settings = app.windows
            .containing(NSPredicate(format: "label CONTAINS 'API key' OR value CONTAINS 'API key'"))
            .firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "the settings window never opened")
        record(settings, app, named: "25-settings")
        settings.buttons[XCUIIdentifierCloseWindow].click()
    }

    // MARK: - Driving helpers

    /// SwiftUI text exposes its string as `value` in some containers and as
    /// `label` in others — every text match checks both.
    private func text(beginning prefix: String) -> NSPredicate {
        NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix)
    }

    /// Never `windows.firstMatch`: a restored auxiliary window can outrank
    /// the shell at launch.
    private func mainWindow(of app: XCUIApplication) -> XCUIElement {
        app.windows
            .matching(NSPredicate(format: "identifier BEGINSWITH 'Ladder.ContentView'"))
            .firstMatch
    }

    private func sidebarRow(_ label: String, in window: XCUIElement) -> XCUIElement {
        let outlineRow = window.outlines.staticTexts[label].firstMatch
        return outlineRow.exists ? outlineRow : window.staticTexts[label].firstMatch
    }

    /// The inspector's form is the rightmost scroll view actually inside the
    /// window — offscreen board columns report frames past the window's edge.
    private func inspectorScrollView(of window: XCUIElement) -> XCUIElement {
        window.scrollViews.allElementsBoundByIndex
            .filter { window.frame.contains($0.frame) }
            .max { $0.frame.minX < $1.frame.minX } ?? window.scrollViews.firstMatch
    }

    /// Lazy forms cull offscreen rows from the tree entirely, so step gently
    /// and let each step settle before deciding the element still isn't there.
    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement) {
        guard scrollView.exists, !(element.exists && element.isHittable) else { return }
        scrollView.scroll(byDeltaX: 0, deltaY: 1600)
        var attempts = 0
        while attempts < 16 {
            _ = element.waitForExistence(timeout: 0.3)
            if element.exists && element.isHittable { return }
            scrollView.scroll(byDeltaX: 0, deltaY: -160)
            attempts += 1
        }
    }

    private func recordAuxWindow(
        openedBy openButton: XCUIElement, headerPrefix: String,
        app: XCUIApplication, named name: String
    ) {
        openButton.click()
        let aux = app.windows.containing(text(beginning: headerPrefix)).firstMatch
        let appeared = aux.waitForExistence(timeout: 10)
        if !appeared { record(app.windows.firstMatch, app, named: "99-debug-\(name)") }
        XCTAssertTrue(appeared, "no window headed '\(headerPrefix)…' opened")
        record(aux, app, named: name)
        aux.buttons[XCUIIdentifierCloseWindow].click()
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        field.typeText(text)
    }

    /// The hierarchy dump rides along with every shot: it is the only way to
    /// learn what a screen exposes before writing the step that drives it.
    private func record(_ window: XCUIElement, _ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: window.screenshot())
        shot.name = "\(name).png"
        shot.lifetime = .keepAlways
        add(shot)

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name).txt"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
