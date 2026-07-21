//
//  FonstersScreenshotTests.swift
//  FonstersUITests
//
//  Drives the app and captures App Store screenshots as test attachments.
//  Extract them with:
//    xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>
//
//  Each step is guarded with `exists` / `isHittable` because the same test runs on
//  iPhone (detail is pushed over the list) and iPad (split view shows both at once;
//  nothing is selected at launch).
//
//  Before capturing, the test replaces the auto-generated first-launch seeds (raw
//  device info) with charming, store-friendly seeds. The seeds deliberately use
//  environment keywords (sun, clouds, birds, fireworks, moon, …) so the creature
//  scenes include scenery layers.
//

import XCTest

final class FonstersScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        // A freshly erased iPad simulator can boot into landscape; portrait keeps
        // taps aligned and produces the portrait screenshots the store expects.
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // The launch animation runs ~1s, then first-launch seeding creates creatures.
        Thread.sleep(forTimeInterval: 5)

        // iPad launches with the sidebar visible and nothing selected ("Pick a
        // Fonster" placeholder); select the first creature so the detail column is
        // populated. On iPhone the first creature's detail is already pushed.
        // Right after a first launch the tap can land while seeding/loading is
        // still settling, so retry until the placeholder actually goes away.
        var selectionTries = 0
        while app.staticTexts["Pick a Fonster"].exists && selectionTries < 5 {
            let firstCell = app.cells.firstMatch
            if firstCell.exists && firstCell.isHittable {
                firstCell.tap()
            }
            selectionTries += 1
            Thread.sleep(forTimeInterval: 2)
        }

        // Make the first creature charming before shooting it.
        setNameAndSeed(app, name: "Sunny", seed: "A sunny day with two clouds and 3 birds")
        snap(app, name: "01-creature")

        // iPhone: pop back to the list for the list shot. iPad: the sidebar is
        // already on screen, so the list shot is the same frame minus navigation.
        let backButton = app.navigationBars.buttons.matching(identifier: "Fonsters").firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
            Thread.sleep(forTimeInterval: 2)
            snap(app, name: "02-list")
        } else {
            snap(app, name: "02-list")
        }

        // Open a different creature so the gallery shows some variety.
        let cells = app.cells
        if cells.count > 2 {
            let target = cells.element(boundBy: 2)
            if target.exists && target.isHittable {
                target.tap()
                Thread.sleep(forTimeInterval: 2)
                setNameAndSeed(app, name: "Nova", seed: "Fireworks under the moon with a butterfly")
                snap(app, name: "03-creature-alt")
            }
        }

        // The edit screen: name, source text and the random-source buttons.
        let editButton = detailEditButton(app)
        if editButton.exists && editButton.isHittable {
            editButton.tap()
            Thread.sleep(forTimeInterval: 2)
            snap(app, name: "04-edit")
        }
    }

    /// The navigation bar of the detail column (or the pushed detail screen on
    /// iPhone). The sidebar/list bar is identified by its title "Fonsters"; any
    /// other bar belongs to the detail hierarchy. Element ordering between the two
    /// bars is not stable, so match by identifier instead of position.
    @MainActor
    private func detailNavBar(_ app: XCUIApplication) -> XCUIElement {
        return app.navigationBars
            .matching(NSPredicate(format: "identifier != 'Fonsters'"))
            .firstMatch
    }

    /// The Edit button that opens the creature edit screen. Never the sidebar's
    /// Edit (that one toggles list delete mode and clears the selection).
    @MainActor
    private func detailEditButton(_ app: XCUIApplication) -> XCUIElement {
        return detailNavBar(app).buttons["Edit"]
    }

    /// Opens the edit screen for the currently shown creature, replaces its name and
    /// source text, then navigates back to the detail view. Every step is guarded so
    /// the test still produces screenshots if the UI differs on some platform.
    @MainActor
    private func setNameAndSeed(_ app: XCUIApplication, name: String, seed: String) {
        let editButton = detailEditButton(app)
        guard editButton.exists && editButton.isHittable else { return }
        editButton.tap()
        Thread.sleep(forTimeInterval: 1)

        let nameField = app.textFields["Fonster name"].firstMatch
        if nameField.exists && nameField.isHittable {
            replaceText(app, in: nameField, with: name)
        }

        // The seed field is labelled "Source text"; when empty its placeholder
        // "Type anything..." becomes the matchable label instead.
        let seedField = app.textFields
            .matching(NSPredicate(format: "label == 'Source text' OR label == 'Type anything...' OR placeholderValue == 'Type anything...'"))
            .firstMatch
        if seedField.exists && seedField.isHittable {
            replaceText(app, in: seedField, with: seed)
        }

        // Give the creature a moment to redraw, then pop back to the detail view.
        // The back chevron lives in the detail hierarchy's bar, never the sidebar's.
        Thread.sleep(forTimeInterval: 1)
        let back = detailNavBar(app).buttons.element(boundBy: 0)
        if back.exists && back.isHittable {
            back.tap()
            Thread.sleep(forTimeInterval: 2)
        }
    }

    /// Replaces the text of a field: focus it, Select All from the edit menu if there
    /// is existing text, then type the new text over it.
    @MainActor
    private func replaceText(_ app: XCUIApplication, in element: XCUIElement, with text: String) {
        element.tap()
        Thread.sleep(forTimeInterval: 0.5)
        element.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
        element.typeText(text)
        Thread.sleep(forTimeInterval: 0.5)

        // Dismiss the keyboard (iPad has a dedicated key; harmless no-op elsewhere)
        // so it is out of the way for the back tap and the screenshots.
        let hideKey = app.keyboards.buttons["Hide keyboard"]
        if hideKey.exists && hideKey.isHittable {
            hideKey.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    @MainActor
    private func snap(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
