import XCTest

extension XCTestCase {
    @MainActor func approveParentAction(in app: XCUIApplication) {
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
