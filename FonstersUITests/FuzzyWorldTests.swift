import XCTest

/// Native iOS interaction regression coverage. Uses synthetic fixture memories
/// and a memory-only SwiftData container, never edits or deletes user portraits.
final class FuzzyWorldTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testFuzzyCompanionAndExplorableWorld() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--world-members", "12", "--personality-file", "/tmp/fonsters-ui-\(UUID().uuidString).json"]
        app.launch()
        let play = app.buttons["reaction_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        waitEnabled(play)
        attach(app, "01-fuzzy-meadow")
        play.tap()
        app.buttons["reaction_rest"].tap()
        app.buttons["reaction_greet"].tap()
        for _ in 0..<12 { app.buttons["reaction_hop"].tap() }
        let stage = app.otherElements["fuzzyStage"].firstMatch
        XCTAssertTrue(stage.exists)
        let middle = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43))
        middle.press(forDuration: 0.7, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.48)))
        app.buttons["environment_seaside"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 10)); waitEnabled(play)
        attach(app, "02-fuzzy-seaside")
        app.buttons["environment_moonlit"].tap()
        waitEnabled(play)
        app.buttons["pauseMotion"].tap()
        XCTAssertEqual(app.buttons["pauseMotion"].label, "Resume")
        attach(app, "03-moonlit-paused")
        app.buttons["pauseMotion"].tap()
        app.buttons["openWorld"].tap()
        XCTAssertTrue(app.buttons["pairBall"].waitForExistence(timeout: 20))
        waitEnabled(app.buttons["pairBall"])
        attach(app, "04-world-overview")
        app.buttons["area_park"].tap()
        app.buttons["pairBall"].tap()
        app.buttons["pauseWorld"].tap()
        XCTAssertEqual(app.buttons["pauseWorld"].label, "Resume")
        attach(app, "05-park-friends")
        app.buttons["pauseWorld"].tap()
        app.buttons["area_neighborhood"].tap()
        attach(app, "06-neighborhood")
        app.buttons["closeWorld"].tap()
        XCTAssertTrue(app.buttons["openWorld"].waitForExistence(timeout: 10))
        let returnedSurface = app.otherElements["fuzzyStage"]
        returnedSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43)).press(forDuration: 0.8)
        let response = returnedSurface.value as? String ?? ""
        XCTAssertTrue(["touch", "stroke", "cuddle", "bobs", "ticklish", "high five", "blink"].contains { response.contains($0) }, response)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 1).exists)
        app.tabBars.buttons["Original portrait gallery"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Fonster portrait"].firstMatch.exists)
        attach(app, "07-original-gallery")
    }
    @MainActor func testLegacyLinkSelectsOriginalGallery() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--personality-file", "/tmp/fonsters-link-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["openWorld"].waitForExistence(timeout: 20))
        let data = try JSONSerialization.data(withJSONObject: ["lilac-sun-legacy-link-smoke"])
        let cards = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        app.open(URL(string: "fonsters://import?cards=" + cards)!)
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Original portrait gallery"].isSelected)
        XCTAssertTrue(app.buttons["Fonster portrait"].firstMatch.exists)
        attach(app, "09-legacy-link-gallery")
    }
    @MainActor func testReduceMotionStillAcceptsExpression() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--verify-reduce-motion", "--personality-file", "/tmp/fonsters-still-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["reaction_greet"].waitForExistence(timeout: 20))
        waitEnabled(app.buttons["reaction_greet"])
        app.buttons["reaction_greet"].tap()
        app.buttons["reaction_rest"].tap()
        let surface = app.otherElements["fuzzyStage"]
        XCTAssertTrue((surface.value as? String)?.contains("settles in") == true)
        attach(app, "08-reduce-motion-rest")
    }
    @MainActor private func waitEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
