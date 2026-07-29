import XCTest

/// Launches the real app onto a throwaway store and photographs each screen,
/// so a change can be looked at as the app actually draws it — Lists, controls
/// and window chrome included, none of which `ImageRenderer` can render
/// (LadderTests/SnapshotGallery.swift). Run it with `scripts/snapshots.sh`,
/// which lifts the shots out of the result bundle into `.snapshots/ui/`.
@MainActor
final class ScreenTour: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTourTheApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-LadderScratchStore"]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 30), "app window never appeared")
        record(window, app, named: "01-create-profile")

        let create = window.buttons["Create profile"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        type("Alex Climber", into: window.textFields.element(boundBy: 0))
        type("Staff Engineer", into: window.textFields.element(boundBy: 1))
        record(window, app, named: "02-create-profile-filled")

        create.click()
        XCTAssertTrue(create.waitForNonExistence(timeout: 10), "profile editor never opened")
        record(window, app, named: "03-profile-editor")

        window.radioButtons["Applications"].click()
        record(window, app, named: "04-applications")
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
