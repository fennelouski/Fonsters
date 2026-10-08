import XCTest
import UIKit

final class ProtectedPlayTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--world-members", "6", "--verify-live-inputs", "--world-camera-diagnostics", "--personality-file", "/tmp/protected-play-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let stage = app.otherElements["continuousStage"]
            return stage.exists && (stage.value as? String ?? "").contains("Together, at their own pace")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [mounted], timeout: 35), .completed)
        return app
    }
    @MainActor func testPhoneOrientationsCareSheetsBackAndUndo() {
        let app = launch()
        waitShape(app, landscape: true)
        XCUIDevice.shared.orientation = .landscapeRight
        waitShape(app, landscape: true); waitForRenderedWorld(); attach(app, "protected-01-landscape-lobby")
        XCUIDevice.shared.orientation = .portrait
        waitShape(app, landscape: true)
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 10))
        waitShape(app, landscape: false); waitForRenderedWorld(); attach(app, "protected-02-portrait-care")
        XCUIDevice.shared.orientation = .landscapeRight
        waitShape(app, landscape: false)
        app.buttons["backToLobby"].tap(); waitShape(app, landscape: true)
        app.buttons["createFonster"].tap()
        XCTAssertTrue(app.buttons["cancelProfile"].waitForExistence(timeout: 8))
        waitShape(app, landscape: false); attach(app, "protected-08-portrait-create")
        app.buttons["cancelProfile"].tap(); waitShape(app, landscape: true)
        waitForRenderedWorld(); attach(app, "protected-09-lobby-returned")
    }
    @MainActor func testProtectedPolicyParentCancelApprovalAndLegacyGallery() {
        let app = launch(); waitShape(app, landscape: true)
        app.buttons["familyPrivacyButton"].tap()
        XCTAssertTrue(app.buttons["closeFamilyPrivacy"].waitForExistence(timeout: 5))
        waitShape(app, landscape: false); attach(app, "protected-03-privacy")
        XCTAssertTrue(app.staticTexts["Protected play"].exists)
        app.buttons["closeFamilyPrivacy"].tap(); waitShape(app, landscape: true)
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
        waitShape(app, landscape: false)
        app.buttons["shareFonster"].tap()
        XCTAssertTrue(app.textFields["parentAnswer"].waitForExistence(timeout: 5))
        app.textFields["parentAnswer"].tap(); app.textFields["parentAnswer"].typeText("1")
        app.buttons["approveParentAction"].tap()
        XCTAssertTrue(app.staticTexts["parentIncorrect"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Share visit snapshot"].exists)
        attach(app, "protected-04-parent-task")
        app.buttons["cancelParentAction"].tap()
        XCTAssertTrue(app.buttons["shareFonster"].waitForExistence(timeout: 5))
        app.buttons["shareFonster"].tap(); approveParent(app)
        XCTAssertTrue(app.buttons["Share visit snapshot"].waitForExistence(timeout: 8))
        attach(app, "protected-05-parent-sharing")
        app.buttons["Close sharing"].tap()
        app.buttons["backToLobby"].tap(); waitShape(app, landscape: true)
        app.buttons["undoLobbyControls"].tap(); waitShape(app, landscape: false)
        XCTAssertTrue(app.buttons["backToLobby"].exists)
        app.buttons["backToLobby"].tap(); waitShape(app, landscape: true)
        // Deep links still parse/import through the unchanged legacy renderer,
        // but the export-capable gallery is now an adult area.
        app.open(URL(string: "fonsters://import?cards=WyJsZWdhY3ktcHJvdGVjdGVkLXBsYXkiXQ")!)
        XCTAssertTrue(app.textFields["parentAnswer"].waitForExistence(timeout: 8))
        waitShape(app, landscape: false); approveParent(app)
        XCTAssertTrue(app.buttons["Fonster portrait"].firstMatch.waitForExistence(timeout: 10))
        attach(app, "protected-06-legacy-gallery")
    }
    @MainActor func testInputGateUsesFixturesWithoutHardwarePermission() {
        let app = launch()
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
        waitShape(app, landscape: false)
        app.buttons["panel_Mirror and voice"].tap(); app.buttons["liveMicrophone"].tap()
        XCTAssertTrue(app.buttons["senseEducationContinue"].waitForExistence(timeout: 5)); app.buttons["senseEducationContinue"].tap()
        XCTAssertTrue(app.textFields["parentAnswer"].waitForExistence(timeout: 5))
        app.buttons["cancelParentAction"].tap()
        // Parent modal is presented above an interaction panel. After dismissal
        // the panel remains usable; cancelling grants no microphone access.
        XCTAssertTrue(app.staticTexts["liveInputStatus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["liveInputStatus"].label.contains("Synthetic voice"))
        app.buttons["liveMicrophone"].tap(); approveParent(app)
        XCTAssertTrue(app.staticTexts["liveInputStatus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("Synthetic voice"))
        app.buttons["liveMicrophone"].tap()
        XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("off"))
        XCTAssertFalse(app.textFields["parentAnswer"].exists)
        attach(app, "protected-07-input-gate")
    }
    @MainActor private func approveParent(_ app: XCUIApplication) {
        let education = app.buttons["senseEducationContinue"]
        if education.waitForExistence(timeout: 1) { education.tap() }
        let question = app.staticTexts["parentQuestion"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        let values = question.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(values.count, 2)
        guard values.count == 2 else { return }
        let answer = app.textFields["parentAnswer"]
        answer.tap(); answer.typeText(String(values[0] * values[1])); app.buttons["approveParentAction"].tap()
    }
    @MainActor private func waitShape(_ app: XCUIApplication, landscape: Bool) {
        let started = Date()
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            let shape = landscape ? frame.width > frame.height : frame.height > frame.width
            let stage = app.otherElements["continuousStage"]
            let matches = !stage.exists || (abs(stage.frame.width - frame.width) < 3 && abs(stage.frame.height - frame.height) < 3 && (stage.value as? String ?? "") != "Opening the Fonster world")
            return shape && matches && Date().timeIntervalSince(started) > 1.2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 12), .completed)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    /// Verify the presented GPU frame too: window bounds alone missed a flat
    /// background during renderer rehosting. HUD controls sit outside this crop.
    @MainActor private func waitForRenderedWorld() {
        let pixels = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let image = XCUIScreen.main.screenshot().image.cgImage,
                  let crop = image.cropping(to: CGRect(x: Double(image.width) * 0.32, y: Double(image.height) * 0.32,
                                                       width: Double(image.width) * 0.36, height: Double(image.height) * 0.36)),
                  let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let data = context.data else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            let bytes = data.assumingMemoryBound(to: UInt8.self)
            var colors = Set<UInt32>()
            for offset in stride(from: 0, to: 4096, by: 4) {
                colors.insert(UInt32(bytes[offset] >> 4) << 8 | UInt32(bytes[offset + 1] >> 4) << 4 | UInt32(bytes[offset + 2] >> 4))
            }
            return colors.count > 8
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [pixels], timeout: 15), .completed, "Native world must render beyond the flat background")
    }
}
