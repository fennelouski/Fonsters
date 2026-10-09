import XCTest
import UIKit

final class ContinuousLobbyTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch(still: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--world-members", "6", "--verify-command-fallback", "--personality-file", "/tmp/continuous-lobby-\(UUID().uuidString).json"]
        if still { app.launchArguments.append("--verify-reduce-motion") }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); return app
    }
    @MainActor func testCompactCareKeepsControlsOutsideCreatureArea() throws {
        try verifyCompactCare(largeText: false)
    }
    @MainActor func testCompactCareAtAccessibilityTextSize() throws {
        try verifyCompactCare(largeText: true)
    }
    @MainActor private func verifyCompactCare(largeText: Bool) throws {
        let app = launch(still: true, largeText: largeText)
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        app.buttons["searchFonsters"].tap()
        app.textFields["lobbySearchField"].typeText("moss\n")
        waitEnabled(app.buttons["care_greet"])
        let clear = app.otherElements["careClearArea"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = clear.frame
            return frame.height > app.windows.firstMatch.frame.height * 0.4 && frame.width > 250
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed)
        for id in ["backToLobby", "shareFonster", "care_greet", "care_play", "care_rest", "careCamera", "careMicrophone", "panel_Care", "panel_More interactions", "panel_World and camera", "pauseLobby"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable, id)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, id)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, id)
            XCTAssertFalse(clear.frame.intersects(button.frame), id)
        }
        XCTAssertFalse(clear.frame.intersects(app.staticTexts["careName"].frame))
        attach(app, largeText ? "adaptive-large-text-care" : "adaptive-portrait-care")
        openCareControlPanel("Feelings", in: app)
        XCTAssertTrue(app.buttons["A little low"].waitForExistence(timeout: 5))
        app.buttons["A little low"].tap()
        closeCareControlPanels(in: app)
        XCTAssertTrue(app.buttons["careCamera"].isHittable)
        app.buttons["panel_More interactions"].tap()
        XCTAssertTrue(app.buttons["care_hop"].waitForExistence(timeout: 5))
        app.buttons["care_hop"].tap(); closeCareControlPanels(in: app)
        app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 5))
        attach(app, "adaptive-landscape-lobby")
    }
    @MainActor func testExploreWalkPanFocusAndReturn() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
        waitEnabled(app.buttons["exploreWithFonster"])
        XCTAssertEqual(app.staticTexts["careName"].label, "Moss")
        app.buttons["exploreWithFonster"].tap()
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.width > frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
        let clear = app.otherElements["careClearArea"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); XCTAssertGreaterThan(clear.frame.height, 90)
        for id in ["careCamera", "careMicrophone", "exploreWithFonster", "panel_More interactions", "focusExploringFonster", "panel_Care", "backToLobby"] {
            let button = app.buttons[id]; XCTAssertTrue(button.isHittable, id)
            XCTAssertFalse(clear.frame.intersects(button.frame), id)
        }
        attachDevice("explore-01-landscape-with-name-tag")
        let stage = app.otherElements["continuousStage"]
        // Reachable garden ground in the existing authored world, through the
        // same native gesture used by the person playing with the app.
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.55)).tap()
        if !(stage.value as? String ?? "").contains("Walking to") {
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.54)).tap()
        }
        XCTAssertTrue((stage.value as? String ?? "").contains("Walking to"), stage.value as? String ?? "")
        attachDevice("explore-02-tapped-ground")
        let beforePan = stage.value as? String ?? ""
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35)).press(forDuration: 0.1,
            thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.45)))
        XCTAssertNotEqual(stage.value as? String ?? "", beforePan)
        app.buttons["focusExploringFonster"].tap()
        XCTAssertTrue((stage.value as? String ?? "").contains("position 0.0, 0.0, 0.0"))
        XCTAssertEqual(app.staticTexts["careName"].label, "Moss")
        attachDevice("explore-03-follow-restored")
        app.buttons["exploreWithFonster"].tap()
        XCTAssertTrue(app.buttons["care_greet"].waitForExistence(timeout: 5))
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.height > frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 10), .completed)
        app.buttons["care_greet"].tap(); attach(app, "explore-04-portrait-care")
        app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 5))
    }
    @MainActor func testSpatialSearchCareTouchAndReturn() throws {
        let app = launch()
        let stage = app.otherElements["continuousStage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 25))
        waitRendered(app); attach(app, "continuous-01-lobby")
        XCTAssertFalse(app.buttons["backToLobby"].exists)
        let bounds = app.windows.firstMatch.frame
        XCTAssertEqual(stage.frame.width, bounds.width, accuracy: 2)
        XCTAssertGreaterThan(stage.frame.height, bounds.height * 0.94)
        app.buttons["searchFonsters"].tap()
        let field = app.textFields["lobbySearchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("moss")
        let results = app.images["searchResults"]
        XCTAssertTrue(results.waitForExistence(timeout: 5))
        XCTAssertEqual(results.label, "Front match: Moss")
        attach(app, "continuous-02-search")
        field.typeText("\n")
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 5))
        waitEnabled(app.buttons["care_greet"])
        XCTAssertEqual(app.staticTexts["careName"].label, "Moss")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let colors = self.pixels(app); return Set(colors).count > 15
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 12), .completed)
        attach(app, "continuous-03-care")
        for _ in 0..<12 { app.buttons["care_play"].tap(); app.buttons["care_rest"].tap() }
        app.buttons["care_greet"].tap()
        let touch = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        touch.press(forDuration: 0.8, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.52)))
        let response = stage.value as? String ?? ""
        XCTAssertTrue(["touch", "stroke", "cuddle", "bobs", "ticklish", "high five", "blink"].contains { response.contains($0) }, response)
        attach(app, "continuous-04-contact")
        app.buttons["shareFonster"].tap(); approveParentAction(in: app)
        XCTAssertTrue(app.buttons["Share visit snapshot"].waitForExistence(timeout: 5))
        app.buttons["Close sharing"].tap()
        app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.images["searchResults"].label, "Front match: Moss")
        app.buttons["Clear and close search"].tap()
        XCTAssertTrue(app.textFields["lobbySearchField"].waitForNonExistence(timeout: 3))
        attach(app, "continuous-05-returned")
        // Click the creature itself after spatial search, rather than choosing a
        // surrogate list button. The same stage handles selection and petting.
        app.buttons["searchFonsters"].tap(); field.typeText("moss\n")
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 5))
        app.buttons["backToLobby"].tap()
        let dismissKeyboard = app.buttons["pauseLobby"]
        dismissKeyboard.tap()
        let before = pixels(app)
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.38)).press(forDuration: 0.15, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.56)))
        XCTAssertGreaterThan(zip(pixels(app), before).filter { $0 != $1 }.count, 80)
        attach(app, "continuous-06-camera-paused")
        app.buttons["pauseLobby"].tap()
    }
    @MainActor func testVisualLobbyDemoAndNavigationUndo() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 25)); waitRendered(app)
        attach(app, "demo-01-lobby")
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss")
        if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
        attach(app, "demo-02-search-visible")
        app.textFields["lobbySearchField"].typeText("\n")
        waitEnabled(app.buttons["care_greet"])
        app.buttons["care_greet"].tap(); attach(app, "demo-03-care")
        app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 5))
        app.buttons["undoLobbyControls"].tap()
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["careName"].label, "Moss")
        app.buttons["backToLobby"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        // Touch the rendered search result to enter care, through the native
        // world's transparent input surface rather than a list surrogate.
        let stage = app.otherElements["continuousStage"]
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52)).tap()
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["careName"].label, "Moss")
        attach(app, "demo-04-direct-selection")
        app.buttons["backToLobby"].tap(); app.buttons["Clear and close search"].tap()
        attach(app, "demo-05-returned-lobby")
    }
    @MainActor func testStaticSearchHelpAndLegacyImport() throws {
        let app = launch(still: true)
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 25)); waitRendered(app)
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("iris\n")
        waitEnabled(app.buttons["care_greet"])
        XCTAssertEqual(app.staticTexts["careName"].label, "Iris")
        app.buttons["care_greet"].tap()
        XCTAssertTrue((app.otherElements["continuousStage"].value as? String ?? "").contains("Reduce Motion"))
        app.buttons["panel_More interactions"].tap()
        app.buttons["helpPanel_More interactions"].tap()
        XCTAssertTrue(app.buttons["Close help"].waitForExistence(timeout: 5))
        attach(app, "continuous-07-help-static")
        app.buttons["Close help"].tap(); app.buttons["Close panel"].tap()
        app.buttons["backToLobby"].tap()
        let data = try JSONSerialization.data(withJSONObject: ["lilac-sun-legacy-link-smoke"])
        let cards = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        app.open(URL(string: "fonsters://import?cards=" + cards)!); approveParentAction(in: app)
        XCTAssertTrue(app.buttons["Fonster portrait"].firstMatch.waitForExistence(timeout: 10))
        attach(app, "continuous-08-original-import")
    }
    @MainActor private func waitEnabled(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 20))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)], timeout: 20), .completed)
    }
    @MainActor private func attachDevice(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func waitRendered(_ app: XCUIApplication) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in Set(self.pixels(app)).count > 12 }, object: nil)], timeout: 15), .completed)
    }
    private func pixels(_ app: XCUIApplication) -> [Int] {
        guard let image = app.screenshot().image.cgImage, let crop = image.cropping(to: CGRect(x: CGFloat(image.width)*0.2, y: CGFloat(image.height)*0.35, width: CGFloat(image.width)*0.6, height: CGFloat(image.height)*0.4)) else { return [] }
        var pixels = [UInt8](repeating: 0, count: 32*32*4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 32, height: 32)); let values = bytes.bindMemory(to: UInt8.self)
            var colors: [Int] = []
            for index in stride(from: 0, to: values.count, by: 4) {
                let red = Int(values[index] / 16), green = Int(values[index + 1] / 16), blue = Int(values[index + 2] / 16)
                colors.append(red * 256 + green * 16 + blue)
            }
            return colors
        }
    }
}
