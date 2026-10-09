import XCTest
import UIKit
final class WaypointTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testSaveNameVisitAndMappedSample() {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--verify-reduce-motion", "--personality-file", "/tmp/waypoint-ui-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["savedPlacesButton"].waitForExistence(timeout: 30))
        app.buttons["savedPlacesButton"].tap()
        XCTAssertTrue(app.buttons["waypointSessionStart"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["waypointSort"].exists)
        app.buttons["pinCurrentPlace"].tap()
        let name = app.textFields["waypointNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "My first place")
        app.buttons["saveWaypoint"].tap()
        XCTAssertTrue(app.buttons["visitWaypoint_My first place"].waitForExistence(timeout: 5))
        attach("iphone-saved-place")
        app.buttons["visitWaypoint_My first place"].tap()
        XCTAssertTrue(app.buttons["savedPlacesButton"].waitForExistence(timeout: 5))
        app.buttons["savedPlacesButton"].tap()
        app.buttons["mappedLandmarkCatalog"].tap()
        let mill = app.buttons["mappedFeature_osm:way:285317879"]
        for _ in 0..<12 where !mill.isHittable { app.swipeUp() }
        XCTAssertTrue(mill.exists); mill.tap()
        XCTAssertTrue(app.otherElements["mappedWorldAttribution"].waitForExistence(timeout: 5))
        let settlingStarted = Date()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Date().timeIntervalSince(settlingStarted) > 1.5 && app.frame.width > app.frame.height
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed)
        attach("iphone-real-mapped-windmill")
        app.buttons["returnToSessionStart"].tap()
        XCTAssertFalse(app.otherElements["mappedWorldAttribution"].exists)
        XCTAssertTrue(app.buttons["savedPlacesButton"].exists)
    }
    @MainActor private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
