import XCTest

final class LivingFacesTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testLivingFaceShapesAndProtectedSyntheticCamera() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--world-members", "6", "--verify-live-inputs", "--personality-file", "/tmp/living-faces-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.otherElements["continuousStage"].value as? String ?? "").contains("Together")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [mounted], timeout: 30), .completed)
        attach(app, "faces-01-social-lobby")
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
        XCTAssertTrue(app.buttons["care_greet"].waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["care_greet"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
        app.buttons["care_greet"].tap(); Thread.sleep(forTimeInterval: 0.7)
        attach(app, "faces-02-welcome-smile")
        app.buttons["panel_Feelings"].tap(); app.buttons["A little low"].tap(); app.buttons["Close panel"].tap()
        Thread.sleep(forTimeInterval: 0.5); attach(app, "faces-03-chosen-low")
        app.buttons["care_play"].tap(); Thread.sleep(forTimeInterval: 0.5)
        attach(app, "faces-04-low-during-play")
        app.buttons["panel_Feelings"].tap(); app.buttons["Just here"].tap(); app.buttons["Close panel"].tap()
        app.buttons["care_rest"].tap(); Thread.sleep(forTimeInterval: 0.8)
        attach(app, "faces-05-neutral-rest")
        app.buttons["care_greet"].tap()
        app.buttons["panel_Mirror and voice"].tap(); app.buttons["liveCamera"].tap(); approveParentAction(in: app)
        XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("Synthetic camera"))
        app.swipeUp(); XCTAssertTrue(app.buttons["fixtureSmile"].waitForExistence(timeout: 5))
        app.buttons["fixtureSmile"].tap(); app.buttons["Close panel"].tap(); Thread.sleep(forTimeInterval: 2.6)
        attach(app, "faces-06-smile-shape-fixture")
        app.buttons["panel_Mirror and voice"].tap(); app.swipeUp()
        app.buttons["fixtureFrown"].tap(); app.buttons["Close panel"].tap(); Thread.sleep(forTimeInterval: 2.7)
        attach(app, "faces-07-downturned-shape-fixture")
        app.buttons["pauseLobby"].tap(); attach(app, "faces-08-paused")
        app.buttons["pauseLobby"].tap(); app.buttons["panel_Mirror and voice"].tap()
        app.buttons["stopLiveInputs"].tap(); XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("off"))
        app.buttons["Close panel"].tap(); app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 8))
        attach(app, "faces-09-back-to-social-lobby")
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
