import XCTest
import UIKit

/// Native iOS interaction regression coverage. Uses synthetic fixture memories
/// and a memory-only SwiftData container, never edits or deletes user portraits.
final class FuzzyWorldTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testFuzzyCompanionAndExplorableWorld() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--legacy-playroom", "--verify-manual", "--world-members", "12", "--personality-file", "/tmp/fonsters-ui-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app)
        let play = app.buttons["reaction_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        waitEnabled(play)
        attach(app, "01-fuzzy-meadow")
        play.tap()
        app.buttons["reaction_rest"].tap()
        app.buttons["reaction_greet"].tap()
        app.buttons["panel_More reactions"].tap()
        for _ in 0..<12 { app.buttons["reaction_hop"].tap() }
        app.buttons["Close panel"].tap()
        let stage = app.otherElements["fuzzyStage"].firstMatch
        XCTAssertTrue(stage.exists)
        let middle = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43))
        middle.press(forDuration: 0.7, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.48)))
        app.buttons["panel_Environments"].tap()
        app.buttons["environment_seaside"].tap()
        app.buttons["Close panel"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 10)); waitEnabled(play)
        attach(app, "02-fuzzy-seaside")
        app.buttons["panel_Environments"].tap()
        app.buttons["environment_moonlit"].tap()
        app.buttons["Close panel"].tap()
        waitEnabled(play)
        app.buttons["pauseMotion"].tap()
        XCTAssertEqual(app.buttons["pauseMotion"].label, "Resume")
        attach(app, "03-moonlit-paused")
        app.buttons["pauseMotion"].tap()
        app.buttons["openWorld"].tap()
        XCTAssertTrue(app.buttons["pairBall"].waitForExistence(timeout: 20))
        waitEnabled(app.buttons["pairBall"])
        attach(app, "04-world-overview")
        app.buttons["panel_World areas"].tap()
        app.buttons["area_park"].tap()
        app.buttons["Close panel"].tap()
        app.buttons["pairBall"].tap()
        app.buttons["pauseWorld"].tap()
        XCTAssertEqual(app.buttons["pauseWorld"].label, "Resume")
        attach(app, "05-park-friends")
        app.buttons["pauseWorld"].tap()
        app.buttons["panel_World areas"].tap()
        app.buttons["area_neighborhood"].tap()
        app.buttons["Close panel"].tap()
        attach(app, "06-neighborhood")
        app.buttons["closeWorld"].tap()
        XCTAssertTrue(app.buttons["openWorld"].waitForExistence(timeout: 10))
        // Closing the world remounts the companion's native scene. The existing
        // loading indicator/reaction gate is the readiness signal, not the
        // immediately available world-navigation button.
        waitEnabled(play)
        attach(app, "06a-returned-companion")
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
        app.launchArguments = ["--prototype", "--legacy-playroom", "--verify-manual", "--personality-file", "/tmp/fonsters-link-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app)
        XCTAssertTrue(app.buttons["openWorld"].waitForExistence(timeout: 20))
        let data = try JSONSerialization.data(withJSONObject: ["lilac-sun-legacy-link-smoke"])
        let cards = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        app.open(URL(string: "fonsters://import?cards=" + cards)!)
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Original portrait gallery"].isSelected)
        XCTAssertTrue(app.buttons["Fonster portrait"].firstMatch.exists)
        attach(app, "09-legacy-link-gallery")
    }
    @MainActor func testNativeContactBeforeAndAfterWorld() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--legacy-playroom", "--verify-manual", "--world-members", "12", "--personality-file", "/tmp/fonsters-contact-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app)
        let play = app.buttons["reaction_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20)); waitEnabled(play)
        for returning in [false, true] {
            if returning {
                app.buttons["openWorld"].tap()
                XCTAssertTrue(app.buttons["pairBall"].waitForExistence(timeout: 20)); waitEnabled(app.buttons["pairBall"])
                app.buttons["closeWorld"].tap(); waitEnabled(play)
            }
            let surface = app.otherElements["fuzzyStage"]
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43)).press(forDuration: 0.8)
            let response = surface.value as? String ?? ""
            XCTAssertTrue(["touch", "stroke", "cuddle", "bobs", "ticklish", "high five", "blink"].contains { response.contains($0) }, response)
            attach(app, returning ? "contact-after-world" : "contact-before-world")
        }
    }
    @MainActor func testReduceMotionStillAcceptsExpression() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--legacy-playroom", "--verify-manual", "--verify-reduce-motion", "--personality-file", "/tmp/fonsters-still-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app)
        XCTAssertTrue(app.buttons["reaction_greet"].waitForExistence(timeout: 20))
        waitEnabled(app.buttons["reaction_greet"])
        app.buttons["reaction_greet"].tap()
        app.buttons["reaction_rest"].tap()
        let surface = app.otherElements["fuzzyStage"]
        XCTAssertTrue((surface.value as? String)?.contains("settles in") == true)
        attach(app, "08-reduce-motion-rest")
    }
    @MainActor func testPanelHelpUndoAndFullWindowCamera() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--legacy-playroom", "--verify-manual", "--world-members", "12", "--world-camera-diagnostics", "--personality-file", "/tmp/fonsters-controls-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app); XCTAssertTrue(app.buttons["reaction_play"].waitForExistence(timeout: 20)); waitEnabled(app.buttons["reaction_play"])
        XCTAssertFalse(app.buttons["reaction_hop"].exists, "Secondary reactions should start inside a closed panel")
        app.buttons["help_Reactions"].tap()
        XCTAssertTrue(app.staticTexts["Say hello"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Play"].exists && app.staticTexts["Rest"].exists && app.staticTexts["Stop activity"].exists)
        attach(app, "10-reaction-guide"); app.buttons["Close help"].tap()
        app.buttons["pauseMotion"].tap(); XCTAssertEqual(app.buttons["pauseMotion"].label, "Resume")
        app.buttons["undoControls"].tap(); XCTAssertEqual(app.buttons["pauseMotion"].label, "Pause")
        XCTAssertFalse(app.buttons["undoControls"].isEnabled)
        app.buttons["panel_Environments"].tap(); app.buttons["environment_seaside"].tap(); app.buttons["Close panel"].tap()
        waitEnabled(app.buttons["reaction_play"])
        app.buttons["undoControls"].tap(); waitEnabled(app.buttons["reaction_play"])
        app.buttons["panel_Environments"].tap(); XCTAssertTrue(app.buttons["environment_meadow"].isSelected); app.buttons["Close panel"].tap()
        app.buttons["openWorld"].tap(); XCTAssertTrue(app.buttons["pairBall"].waitForExistence(timeout: 20)); waitEnabled(app.buttons["pairBall"])
        let stage = app.otherElements["worldStage"].firstMatch
        XCTAssertGreaterThan(stage.frame.width / app.windows.firstMatch.frame.width, 0.98)
        XCTAssertGreaterThan(stage.frame.height / app.windows.firstMatch.frame.height, 0.98)
        assertWorldRendered(app)
        attach(app, "11a-world-before-pause")
        app.buttons["pauseWorld"].tap(); let before = stage.value as? String
        let beforeImage = worldPixels(app)
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.42)).press(forDuration: 0.15, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.60)))
        let after = stage.value as? String
        let cameraEvidence = XCTAttachment(string: "Before: \(before ?? "missing")\nAfter: \(after ?? "missing")")
        cameraEvidence.name = "camera-state-after-drag"; cameraEvidence.lifetime = .keepAlways; add(cameraEvidence)
        XCTAssertNotEqual(after?.components(separatedBy: "Camera angle").last, before?.components(separatedBy: "Camera angle").last, "Dragging must change the camera angles while paused")
        let afterImage = worldPixels(app)
        let changedSamples = zip(afterImage, beforeImage).filter { $0 != $1 }.count
        XCTAssertGreaterThan(changedSamples, 100, "Camera movement must substantially change the actual scene pixels, not just control state")
        attach(app, "11b-camera-orbit")
        app.buttons["undoWorldControls"].tap(); XCTAssertEqual((stage.value as? String)?.components(separatedBy: "Camera angle").last, before?.components(separatedBy: "Camera angle").last)
        attach(app, "11-full-window-world")
        assertWorldRendered(app)
        app.buttons["pauseWorld"].tap(); app.buttons["pairBall"].tap(); app.buttons["stopWorldActivity"].tap()
        XCTAssertTrue((stage.value as? String)?.contains("Activity stopped") == true)
        app.buttons["panel_World controls"].tap(); app.buttons["helpPanel_World controls"].tap()
        XCTAssertTrue(app.staticTexts["Follow selected"].waitForExistence(timeout: 5))
        attach(app, "12-camera-guide")
        // Native accessibility omits clipped rows from a scrollable sheet.
        // Exercise the guide as a user would instead of querying unseen rows.
        let guide = app.scrollViews.firstMatch
        for title in ["Tilt up", "Raise camera", "Wander"] {
            let item = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", title)).firstMatch
            for _ in 0..<12 {
                if item.exists && item.isHittable { break }
                guide.swipeUp()
            }
            XCTAssertTrue(item.exists && item.isHittable, "The panel guide must include " + title)
        }
        attach(app, "13-camera-guide-motion")
        for _ in 0..<12 {
            if app.buttons["Close help"].isHittable { break }
            guide.swipeDown()
        }
        app.buttons["Close help"].tap(); app.buttons["Close panel"].tap()
    }
    @MainActor func testDirectWorldCamera() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--legacy-world", "--world-members", "12", "--world-camera-diagnostics", "--personality-file", "/tmp/fonsters-camera-\(UUID().uuidString).json"]
        app.launch(); approveParentAction(in: app)
        XCTAssertTrue(app.buttons["pairBall"].waitForExistence(timeout: 20)); waitEnabled(app.buttons["pairBall"])
        assertWorldRendered(app)
        app.buttons["pauseWorld"].tap()
        let stage = app.otherElements["worldStage"].firstMatch
        let before = worldPixels(app)
        attach(app, "direct-camera-before")
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.42)).press(forDuration: 0.15, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.60)))
        attach(app, "direct-camera-after")
        XCTAssertGreaterThan(zip(worldPixels(app), before).filter { $0 != $1 }.count, 100)
    }
    @MainActor private func waitEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    /// Inspect the actual GPU screenshot rather than equating scene construction
    /// or accessibility readiness with a visible world. Ignore the HUD edges.
    @MainActor private func assertWorldRendered(_ app: XCUIApplication) {
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in Set(self.worldPixels(app)).count > 12 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 12), .completed, "The world must appear in the actual rendered frame, including while paused")
    }
    private func worldPixels(_ app: XCUIApplication) -> [Int] {
        guard let image = app.screenshot().image.cgImage,
              let crop = image.cropping(to: CGRect(x: CGFloat(image.width) * 0.15, y: CGFloat(image.height) * 0.3,
                                                   width: CGFloat(image.width) * 0.7, height: CGFloat(image.height) * 0.5)) else { return [] }
        var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
                                          bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            let values = bytes.bindMemory(to: UInt8.self)
            var colors = [Int]()
            for index in stride(from: 0, to: values.count, by: 4) {
                let red = Int(values[index] / 16)
                let green = Int(values[index + 1] / 16)
                let blue = Int(values[index + 2] / 16)
                colors.append(red * 256 + green * 16 + blue)
            }
            return colors
        }
    }
}
