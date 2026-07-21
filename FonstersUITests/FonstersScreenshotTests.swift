//
//  FonstersScreenshotTests.swift
//  FonstersUITests
//
//  Drives the app and captures App Store screenshots as test attachments.
//  Extract them with:
//    xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>
//
//  Each step is guarded with `exists` / `isHittable` because the same test runs on
//  iPhone (detail is pushed over the list) and iPad (split view shows both at once).
//

import XCTest

final class FonstersScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        // The launch animation runs ~1s, then first-launch seeding creates creatures.
        Thread.sleep(forTimeInterval: 5)
        snap(app, name: "01-creature")

        // iPhone: pop back to the list. iPad: the sidebar is already on screen, so the
        // first nav-bar button is something else and this is skipped.
        let backButton = app.navigationBars.buttons.matching(identifier: "Fonsters").firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
            Thread.sleep(forTimeInterval: 2)
            snap(app, name: "02-list")

            // Open a different creature so the gallery shows some variety.
            let cells = app.cells
            if cells.count > 2 {
                let target = cells.element(boundBy: 2)
                if target.exists && target.isHittable {
                    target.tap()
                    Thread.sleep(forTimeInterval: 2)
                    snap(app, name: "03-creature-alt")
                }
            }
        } else {
            snap(app, name: "02-list")
        }

        // The edit screen: name, source text and the random-source buttons.
        let editButton = app.buttons["Edit"].firstMatch
        if editButton.exists && editButton.isHittable {
            editButton.tap()
            Thread.sleep(forTimeInterval: 2)
            snap(app, name: "04-edit")
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
