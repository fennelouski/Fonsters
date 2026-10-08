import XCTest

final class InterestEditorTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--verify-personal-library", "--verify-live-inputs", "--library-store", "/tmp/interest-library-\(UUID().uuidString).sqlite", "--personality-file", "/tmp/interest-memory-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["createFonster"].waitForExistence(timeout: 35))
        app.buttons["createFonster"].tap()
        XCTAssertTrue(app.textFields["profileName"].waitForExistence(timeout: 8))
        return app
    }
    @MainActor func testMultipleSourcesPrivateDraftResetAndSave() throws {
        let app = launch()
        let name = app.textFields["profileName"]; name.tap(); name.typeText("Luma")
        let story = app.descendants(matching: .any)["profileBackground"]
        story.tap(); story.typeText("This private story should stay with me.")
        attach(app, "editor-01-story")
        app.buttons["profileTab_screen"].tap()
        let field = app.descendants(matching: .any)["profileShows"]; field.tap(); field.typeText("Bluey")
        let results = app.buttons["profileShowsResults"]; XCTAssertTrue(results.waitForExistence(timeout: 5)); results.tap()
        XCTAssertTrue(app.buttons["selectInterest_bluey-official"].waitForExistence(timeout: 5))
        app.buttons["selectInterest_bluey-official"].tap()
        attach(app, "editor-02-first-source")
        app.buttons["Next source"].tap()
        XCTAssertTrue(app.buttons["selectInterest_bluey-wikipedia"].waitForExistence(timeout: 5))
        app.buttons["selectInterest_bluey-wikipedia"].tap()
        app.buttons["closeInterestRecords"].tap()
        XCTAssertTrue(app.buttons["interestChip_bluey-official"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["interestChip_bluey-wikipedia"].exists)
        app.swipeUp()
        attach(app, "editor-03-multiple-chips")
        app.buttons["profileTab_places"].tap()
        let places = app.descendants(matching: .any)["profilePlaces"]; places.tap(); places.typeText("Disneyland")
        XCTAssertTrue(app.buttons["profilePlacesResults"].waitForExistence(timeout: 5)); app.buttons["profilePlacesResults"].tap()
        XCTAssertTrue(app.buttons["selectInterest_disneyland-official"].waitForExistence(timeout: 5)); app.buttons["selectInterest_disneyland-official"].tap()
        attach(app, "editor-04-place-record")
        app.buttons["closeInterestRecords"].tap()
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.staticTexts["careName"].waitForExistence(timeout: 15)); XCTAssertEqual(app.staticTexts["careName"].label, "Luma")
        app.buttons["editFonsterProfile"].tap()
        XCTAssertTrue(story.waitForExistence(timeout: 5)); XCTAssertEqual(story.value as? String, "This private story should stay with me.")
        app.buttons["profileTab_screen"].tap(); XCTAssertTrue(app.buttons["interestChip_bluey-official"].exists); XCTAssertTrue(app.buttons["interestChip_bluey-wikipedia"].exists)
        field.tap(); field.typeText(", private unknown phrase")
        app.buttons["Reset unsaved profile changes"].tap()
        XCTAssertEqual(field.value as? String, "Bluey")
        app.buttons["cancelProfile"].tap()
        app.buttons["shareFonster"].tap(); approveParentAction(in: app)
        let toggle = app.buttons["shareBiography"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertEqual(toggle.value as? String, "Excluded")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "Included")
        XCTAssertTrue(app.buttons["interestChip_bluey-official"].waitForExistence(timeout: 5))
        toggle.tap(); XCTAssertEqual(toggle.value as? String, "Excluded")
        XCTAssertFalse(app.buttons["interestChip_bluey-official"].exists)
        toggle.tap(); XCTAssertEqual(toggle.value as? String, "Included")
        XCTAssertTrue(app.buttons["interestChip_bluey-official"].exists)
        XCTAssertFalse(app.staticTexts["This private story should stay with me."].exists)
        XCTAssertFalse(app.staticTexts["private unknown phrase"].exists)
        attach(app, "editor-05-recipient-preview")
    }
    @MainActor func testCameraOptInCancelAndPrivateUnmatchedText() throws {
        let app = launch()
        let camera = app.buttons["editorCamera"]
        XCTAssertTrue(camera.exists); camera.tap()
        XCTAssertTrue(app.buttons["senseEducationContinue"].waitForExistence(timeout: 5)); app.buttons["senseEducationContinue"].tap()
        XCTAssertTrue(app.textFields["parentAnswer"].waitForExistence(timeout: 5))
        attach(app, "editor-06-camera-review")
        app.buttons["cancelParentAction"].tap()
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); XCTAssertEqual(camera.label, "Imitate me with the camera")
        camera.tap(); approveParentAction(in: app)
        XCTAssertTrue(camera.waitForExistence(timeout: 5)); XCTAssertEqual(camera.label, "Turn editor camera off")
        attach(app, "editor-07-camera-enabled-fixture")
        camera.tap(); XCTAssertEqual(camera.label, "Imitate me with the camera")
        app.buttons["profileTab_likes"].tap()
        let likes = app.descendants(matching: .any)["profileLikes"]; likes.tap(); likes.typeText("my private invented interest")
        XCTAssertTrue(app.descendants(matching: .any)["profileLikesPrivate"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileLikesResults"].exists)
        attach(app, "editor-08-unmatched-private")
        app.buttons["cancelProfile"].tap()
        XCTAssertTrue(app.buttons["createFonster"].waitForExistence(timeout: 10))
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
