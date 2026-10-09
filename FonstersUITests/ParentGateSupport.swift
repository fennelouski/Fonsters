import XCTest

extension XCTestCase {
    @MainActor func approveParentAction(in app: XCUIApplication) {
        let education = app.buttons["senseEducationContinue"]
        if education.waitForExistence(timeout: 1) { education.tap() }
        let question = app.staticTexts["parentQuestion"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        let values = question.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(values.count, 2)
        guard values.count == 2 else { return }
        let answer = app.textFields["parentAnswer"]
        answer.tap(); answer.typeText(String(values[0] * values[1]))
        app.buttons["approveParentAction"].tap()
        XCTAssertTrue(app.textFields["parentAnswer"].waitForNonExistence(timeout: 5))
    }
}

/// Care's secondary controls live in panels so the creature stays unobstructed.
@MainActor func openCareControlPanel(_ title: String, in app: XCUIApplication) {
    let target = app.buttons["panel_" + title]
    if !target.isHittable {
        let parent = app.buttons[title == "Dance world" ? "panel_World and camera" : "panel_Care"]
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        parent.tap()
    }
    XCTAssertTrue(target.waitForExistence(timeout: 5))
    target.tap()
}
@MainActor func closeCareControlPanels(in app: XCUIApplication) {
    for _ in 0..<3 {
        let close = app.buttons["Close panel"].firstMatch
        // A parent-check sheet eases out before revealing its presenting panel.
        guard close.waitForExistence(timeout: 2) else { return }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        guard XCTWaiter.wait(for: [ready], timeout: 3) == .completed else { return }
        close.tap()
    }
}
