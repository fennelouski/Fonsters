import XCTest

final class WelcomeAndSensesTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testFirstFriendExploreAndVisibleSenseEducation() {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-live-inputs", "--verify-reduce-motion", "--personality-file", "/tmp/welcome-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["welcomeShuffle"].waitForExistence(timeout: 30))
        app.buttons["welcomeShuffle"].tap(); app.buttons["welcomeChoose"].tap()
        XCTAssertTrue(app.buttons["welcomeExplore"].waitForExistence(timeout: 5))
        attach(app, "welcome-choose-destination")
        app.buttons["welcomeExplore"].tap()
        XCTAssertTrue(app.buttons["Start exploring"].waitForExistence(timeout: 5)); app.buttons["Start exploring"].tap()
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("my fonster\n")
        XCTAssertTrue(app.buttons["careCamera"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["careMicrophone"].exists)
        app.buttons["careCamera"].tap()
        XCTAssertTrue(app.buttons["senseEducationContinue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["parentAnswer"].exists)
        attach(app, "camera-education")
        approveParentAction(in: app)
        XCTAssertTrue(app.buttons["careCamera"].waitForExistence(timeout: 5))
        app.buttons["careCamera"].tap()
        app.buttons["careMicrophone"].tap()
        XCTAssertTrue(app.buttons["senseEducationContinue"].waitForExistence(timeout: 5))
        attach(app, "microphone-education")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.textFields["parentAnswer"].exists)
    }
    @MainActor func testPersonalityChoicesAndReturningLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-reduce-motion", "--library-store", "/tmp/welcome-library-\(UUID().uuidString)/store.sqlite", "--personality-file", "/tmp/welcome-personality-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["welcomeChoose"].waitForExistence(timeout: 30)); app.buttons["welcomeChoose"].tap()
        app.buttons["welcomePersonality"].tap()
        XCTAssertTrue(app.buttons["Learn through movement"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Learn through voice"].exists); XCTAssertTrue(app.buttons["Play together"].exists); XCTAssertTrue(app.buttons["Name and interests"].exists)
        attach(app, "welcome-personality-paths")
        app.buttons["Explore instead"].tap(); app.buttons["Start exploring"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["welcomeChoose"].waitForExistence(timeout: 3))
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("my fonster\n")
        XCTAssertTrue(app.buttons["careCamera"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["careName"].label, "My Fonster")
        attach(app, "welcome-returning-care")
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
