import XCTest

final class LiveMovesTests: XCTestCase {
 override func setUpWithError() throws { continueAfterFailure = false }
 @MainActor private func launch(still: Bool = false) -> XCUIApplication {
  let app = XCUIApplication()
  app.launchArguments = ["--prototype", "--verify-manual", "--world-members", "6", "--verify-live-inputs", "--personality-file", "/tmp/live-moves-\(UUID().uuidString).json"]
  if still { app.launchArguments.append("--verify-reduce-motion") }
  app.launch(); XCTAssertTrue(app.buttons["searchFonsters"].waitForExistence(timeout: 25))
  app.buttons["searchFonsters"].tap(); app.textFields["lobbySearchField"].typeText("moss\n")
  XCTAssertTrue(app.buttons["care_play"].waitForExistence(timeout: 10))
  let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["care_play"])
  XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
  return app
 }
 @MainActor func testDanceWorldAndSyntheticVoicePractice() throws {
  let app = launch()
  openCareControlPanel("Dance world", in: app); app.buttons["dance_disco"].tap()
  app.buttons["danceConfetti"].tap(); app.buttons["danceBalloons"].tap(); closeCareControlPanels(in: app)
  attach(app, "live-01-disco-world")
  app.buttons["pauseLobby"].tap(); attach(app, "live-02-paused-party")
  app.buttons["pauseLobby"].tap()
  openCareControlPanel("Mirror and voice", in: app)
  app.buttons["liveMicrophone"].tap(); approveParentAction(in: app)
  XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("Synthetic voice"))
  app.swipeUp()
  XCTAssertTrue(app.buttons["fixtureSleep"].waitForExistence(timeout: 5)); app.buttons["fixtureSleep"].tap()
  XCTAssertEqual(app.staticTexts["liveInputStatus"].label, "Heard sleep.")
  closeCareControlPanels(in: app); attach(app, "live-03-spoken-sleep-fixture")
  openCareControlPanel("Mirror and voice", in: app)
  app.buttons["fixtureDance"].tap(); closeCareControlPanels(in: app)
  attach(app, "live-04-spoken-dance-fixture")
  openCareControlPanel("Mirror and voice", in: app); app.buttons["liveCamera"].tap(); approveParentAction(in: app)
  app.buttons["lessonWave"].tap(); app.swipeUp(); app.buttons["fixtureRehearsal"].tap()
  let keep = app.buttons["keepLesson"]
  XCTAssertTrue(keep.waitForExistence(timeout: 10))
  let complete = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: keep)
  XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 15), .completed)
  attach(app, "live-05-ready-to-keep-practice")
  keep.tap(); XCTAssertTrue(app.buttons["undoLesson"].isEnabled); app.buttons["undoLesson"].tap()
  XCTAssertFalse(app.buttons["undoLesson"].isEnabled)
  app.buttons["stopLiveInputs"].tap(); XCTAssertTrue(app.staticTexts["liveInputStatus"].label.contains("off"))
  closeCareControlPanels(in: app)
  openCareControlPanel("Dance world", in: app); app.buttons["endDance"].tap(); closeCareControlPanels(in: app)
  attach(app, "live-06-restored-world")
 }
 @MainActor func testStaticPartyAndPermissionHelp() throws {
  let app = launch(still: true)
  openCareControlPanel("Dance world", in: app); app.buttons["dance_disco"].tap()
  XCTAssertFalse(app.buttons["danceConfetti"].isEnabled); XCTAssertFalse(app.buttons["danceBalloons"].isEnabled)
  closeCareControlPanels(in: app)
  XCTAssertTrue((app.otherElements["continuousStage"].value as? String ?? "").contains("Reduce Motion"))
  attach(app, "live-07-static-party")
  openCareControlPanel("Mirror and voice", in: app); app.buttons["helpPanel_Mirror and voice"].tap()
  XCTAssertTrue(app.buttons["Close help"].waitForExistence(timeout: 5)); attach(app, "live-08-input-help")
  app.buttons["Close help"].tap(); closeCareControlPanels(in: app)
 }
 @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
  let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
 }
}
