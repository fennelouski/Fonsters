import XCTest

final class PersonalFonsterLibraryTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testOverheadOwnedNameOpensProfile() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--verify-personal-library", "--library-store", "/tmp/overhead-library-\(UUID().uuidString).sqlite", "--personality-file", "/tmp/overhead-memory-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 30))
        waitReady(app)
        XCTAssertFalse(app.buttons["editFonsterProfile"].exists)
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("biscuit\n")
        XCTAssertTrue(app.buttons["editFonsterProfile"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["editFonsterProfile"].value as? String, "Biscuit")
        let nameButton = app.buttons["editFonsterProfile"]
        XCTAssertTrue(nameButton.isHittable); XCTAssertGreaterThanOrEqual(nameButton.frame.height, 44)
        nameButton.tap()
        XCTAssertTrue(app.textFields["profileName"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.textFields["profileName"].value as? String, "Biscuit")
        app.buttons["cancelProfile"].tap()
        XCTAssertTrue(nameButton.waitForExistence(timeout: 10))
        app.buttons["backToLobby"].tap()
        XCTAssertFalse(app.buttons["editFonsterProfile"].exists)
    }
    @MainActor func testCreateProfileCancelShareAndPersist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype", "--verify-manual", "--verify-personal-library", "--verify-command-fallback", "--library-store", "/tmp/personal-library-\(UUID().uuidString).sqlite", "--personality-file", "/tmp/personal-memory-\(UUID().uuidString).json"]
        app.launch()
        XCTAssertTrue(app.buttons["createFonster"].waitForExistence(timeout: 30))
        waitReady(app)
        let starterLabel = app.otherElements["continuousStage"].label
        XCTAssertFalse(starterLabel.contains("Coral, Moss, Iris, Tide"))
        attach(app, "personal-01-account-starters")
        app.buttons["createFonster"].tap()
        let name = app.textFields["profileName"]
        XCTAssertTrue(name.waitForExistence(timeout: 8)); name.tap(); name.typeText("Luma")
        let background = app.descendants(matching: .any)["profileBackground"]
        background.tap(); background.typeText("Born beneath a tiny paper moon.")
        app.buttons["profileTab_likes"].tap()
        field(app, "profileLikes", "Comets, Picnics"); field(app, "profileDislikes", "Loud alarms")
        app.buttons["profileTab_screen"].tap()
        field(app, "profileMovies", "Spirited Away"); field(app, "profileShows", "Bluey")
        XCTAssertTrue(app.buttons["profileShowsResults"].waitForExistence(timeout: 5)); app.buttons["profileShowsResults"].tap()
        app.buttons["selectInterest_bluey-official"].tap(); app.buttons["closeInterestRecords"].tap()
        app.buttons["profileTab_people"].tap()
        field(app, "profileCreators", "Hayao Miyazaki"); field(app, "profileCelebrities", "LeVar Burton")
        attach(app, "personal-02-create-and-favorites")
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["backToLobby"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.buttons["editFonsterProfile"].value as? String, "Luma")
        attach(app, "personal-03-custom-care")
        app.buttons["editFonsterProfile"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 8)); XCTAssertEqual(name.value as? String, "Luma")
        XCTAssertEqual(background.value as? String, "Born beneath a tiny paper moon.")
        name.tap(); name.typeText(" temporary")
        app.buttons["cancelProfile"].tap()
        XCTAssertEqual(app.buttons["editFonsterProfile"].value as? String, "Luma")
        app.buttons["shareFonster"].tap(); approveParentAction(in: app)
        let profileSwitch = app.buttons["shareBiography"]
        XCTAssertTrue(profileSwitch.waitForExistence(timeout: 5)); XCTAssertEqual(profileSwitch.value as? String, "Excluded")
        profileSwitch.tap()
        XCTAssertEqual(profileSwitch.value as? String, "Included")
        XCTAssertFalse(app.staticTexts["Born beneath a tiny paper moon."].exists)
        XCTAssertTrue(app.buttons["interestChip_bluey-official"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share visit snapshot"].exists)
        attach(app, "personal-04-opt-in-sharing")
        app.buttons["Close sharing"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 25)); waitReady(app)
        app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("Luma\n")
        XCTAssertTrue(app.buttons["editFonsterProfile"].waitForExistence(timeout: 10))
        app.buttons["editFonsterProfile"].tap()
        XCTAssertTrue(background.waitForExistence(timeout: 5)); XCTAssertEqual(background.value as? String, "Born beneath a tiny paper moon.")
        app.buttons["profileTab_likes"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["profileLikes"].value as? String, "Comets, Picnics")
        XCTAssertEqual(app.descendants(matching: .any)["profileDislikes"].value as? String, "Loud alarms")
        app.buttons["profileTab_screen"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["profileMovies"].value as? String, "Spirited Away")
        XCTAssertEqual(app.descendants(matching: .any)["profileShows"].value as? String, "Bluey")
        app.buttons["profileTab_people"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["profileCreators"].value as? String, "Hayao Miyazaki")
        XCTAssertEqual(app.descendants(matching: .any)["profileCelebrities"].value as? String, "LeVar Burton")
        attach(app, "personal-05-reopened-profile")
        name.tap(); name.typeText(" Bee")
        let renamed = name.value as! String
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["editFonsterProfile"].waitForExistence(timeout: 15)); XCTAssertEqual(app.buttons["editFonsterProfile"].value as? String, renamed)
        app.buttons["backToLobby"].tap(); app.buttons["Clear and close search"].tap()
        let finalLabel = app.otherElements["continuousStage"].label
        XCTAssertTrue(finalLabel.contains(renamed)); XCTAssertTrue(starterLabel.replacingOccurrences(of: "Explorable Fonster world with ", with: "").split(separator: ",").allSatisfy { finalLabel.contains($0.trimmingCharacters(in: .whitespaces)) })
        app.buttons["createFonster"].tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Never saved"); app.buttons["cancelProfile"].tap()
        XCTAssertFalse(app.otherElements["continuousStage"].label.contains("Never saved"))
    }
    @MainActor private func field(_ app: XCUIApplication, _ id: String, _ text: String) {
        let field = app.descendants(matching: .any)[id]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(text)
    }
    @MainActor private func waitReady(_ app: XCUIApplication) {
        let stage = app.otherElements["continuousStage"]
        let predicate = NSPredicate { _, _ in
            let value = stage.value as? String ?? ""
            return stage.label.contains("Biscuit") && !value.isEmpty
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: stage)], timeout: 20), .completed)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
