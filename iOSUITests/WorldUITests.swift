import XCTest

final class WorldUITests: XCTestCase {
    func testRoomClientBattlesThroughRealRelay() throws {
        let app = launch(); app.buttons["action-CONNECTION"].tap()
        let server = app.textFields["roomServer"]
        XCTAssertTrue(server.waitForExistence(timeout: 5))
        replaceText(server,with: "ws://127.0.0.1:8765"); app.buttons["roomKeyboardDone"].tap()
        replaceText(app.textFields["roomCode"],with: "UITEST01"); app.buttons["roomKeyboardDone"].tap()
        let join = app.buttons["joinRoom"]; scrollTo(join,in: app); join.tap()
        let confirm = app.buttons["confirmConnection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15)); confirm.tap()
        XCTAssertTrue(element(app,"connectionArena").waitForExistence(timeout: 5))
        attachScreenshot("sideload-room-battle")
        app.buttons["pageDone"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["gameStateProbe"],containing: "dp=19;",timeout: 5))
        XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains("battles=1;connections=1"))
    }
    func testSideloadRoomEntryRejectsInsecurePublicAddress() throws {
        let app = launch(); app.buttons["action-CONNECTION"].tap()
        let server = app.textFields["roomServer"]
        XCTAssertTrue(server.waitForExistence(timeout: 5))
        replaceText(server,with: "ws://example.com"); app.buttons["roomKeyboardDone"].tap()
        replaceText(app.textFields["roomCode"],with: "ABC123"); app.buttons["roomKeyboardDone"].tap()
        let join = app.buttons["joinRoom"]; scrollTo(join,in: app); join.tap()
        XCTAssertTrue(waitFor(app.staticTexts["connectionNotice"],containing: "wss",timeout: 5))
    }
    func testFeedingAndRefusalKeepFoodAndCharacterInsideLCD() throws {
        for refusing in [false,true] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing","--ui-testing-hatched","--ui-testing-slow-care"] + (refusing ? ["--ui-testing-feed-refusal"] : [])
            app.launch()
            XCTAssertTrue(app.buttons["action-FOOD"].waitForExistence(timeout: 10))
            app.buttons["action-FOOD"].tap(); app.buttons["lcdFeed"].tap()
            let probe = app.staticTexts["feedingLayoutProbe"]
            XCTAssertTrue(probe.waitForExistence(timeout: 2))
            XCTAssertTrue(probe.label.contains(refusing ? "pose=refuse" : "pose=eat"))
            XCTAssertTrue(probe.label.contains("petWithin=true;foodWithin=true"))
            XCTAssertFalse(app.buttons["lcdFeed"].isEnabled)
            attachScreenshot(refusing ? "food-refusal-layout" : "food-eating-layout")
            let enabled = NSPredicate { _,_ in app.buttons["lcdFeed"].isEnabled }
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: enabled,evaluatedWith: app)],timeout: 10),.completed)
            if refusing {
                // The refusal notice must not intercept the food button after the animation ends.
                app.buttons["lcdFeed"].tap()
                XCTAssertTrue(probe.waitForExistence(timeout: 2)); XCTAssertTrue(probe.label.contains("pose=refuse"))
            }
            app.buttons["hardware-C"].tap()
            XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains(refusing ? "meals=0;weight=20;" : "meals=1;weight=21;"))
            app.terminate()
        }
    }
    func testVersionTwoCreatesItsOwnEggAndRules() throws {
        let app = launch()
        app.buttons["action-DIGIVICE"].tap(); app.buttons["profile-dmc-ver2"].tap()
        XCTAssertTrue(app.buttons["create-device-dmc-ver2"].waitForExistence(timeout: 5))
        app.buttons["create-device-dmc-ver2"].tap()
        XCTAssertTrue(app.staticTexts["Ver.2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["普尼兽"].waitForExistence(timeout: 12))
    }
    func testEnglishSettingsAndCloudBackupEntry() throws { verifyLanguageAndCloud("English") }
    func testJapaneseSettingsAndCloudBackupEntry() throws { verifyLanguageAndCloud("日本語") }
    func testTraditionalSettingsAndCloudBackupEntry() throws { verifyLanguageAndCloud("繁體中文") }
    private func verifyLanguageAndCloud(_ languageName: String) {
        let app = launch()
        openSettings(app)
        let language = app.buttons["appLanguage"]
        scrollTo(language,in: app); language.tap(); app.buttons[languageName].tap()
        let cloud = app.buttons["cloudChooseFolder"]; scrollTo(cloud,in: app)
        XCTAssertTrue(cloud.label.contains("iCloud Drive"))
        if languageName == "English" { XCTAssertFalse(cloud.label.contains("选择")) }
        app.buttons["pageDone"].tap()
        XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains("font=true"))
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    func testHatchingAndHardwareNavigation() throws {
        let app = launch(hatched: false)
        XCTAssertTrue(app.buttons["startHatching"].waitForExistence(timeout: 10))
        app.buttons["startHatching"].tap()
        XCTAssertTrue(app.buttons["hardware-B"].waitForExistence(timeout: 5))
        app.buttons["hardware-B"].tap()
        XCTAssertTrue(element(app,"lcdClock").waitForExistence(timeout: 5))
        app.buttons["hardware-C"].tap(); app.buttons["hardware-A"].tap(); app.buttons["hardware-B"].tap()
        XCTAssertTrue(element(app,"lcdStatusPage").waitForExistence(timeout: 5))
        attachScreenshot("lcd-hatching-status")
    }
    func testLCDFeedingTrainingAndActualStats() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["action-FOOD"].waitForExistence(timeout: 10))
        app.buttons["action-FOOD"].tap(); app.buttons["lcdFeed"].tap()
        app.buttons["hardware-C"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["gameStateProbe"],containing: "meals=1;weight=21;",timeout: 5))
        app.buttons["action-TRAIN"].tap(); app.buttons["beginTraining"].tap()
        for key in ["B","B","B","A","A"] { app.buttons["training-"+key].tap() }
        XCTAssertTrue(waitFor(app.staticTexts["lcdTrainingResult"],containing: "5/5",timeout: 5))
        app.buttons["hardware-C"].tap()
        XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains("training=1;"))
        attachScreenshot("lcd-training-result")
    }
    func testClassicModeUsesHardwareAndHidesHiddenConditions() throws {
        let app = launch(); openSettings(app)
        app.buttons["play-style-classic"].tap(); app.navigationBars.buttons["完成"].tap()
        XCTAssertFalse(app.buttons["action-FOOD"].isEnabled)
        app.buttons["hardware-A"].tap(); app.buttons["hardware-B"].tap()
        XCTAssertTrue(element(app,"lcdStatusPage").exists)
        XCTAssertFalse(app.staticTexts["本阶段照顾失误"].exists)
        app.buttons["hardware-C"].tap(); openSettings(app)
        app.buttons["play-style-enhanced"].tap(); app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["action-FOOD"].isEnabled)
    }
    func testOriginalColorAndFreeDisplaySwitching() throws {
        let app = launch(); attachScreenshot("large-color-home")
        openSettings(app)
        for mode in ["lcd","advanced","color"] {
            let choice = app.buttons["display-mode-\(mode)"]
            scrollTo(choice,in: app); choice.tap()
            XCTAssertEqual(choice.value as? String,"已选择")
            attachScreenshot("display-"+mode)
        }
    }
    func testSandboxTimeAndReturnPreserveFormalCare() throws {
        let app = launch(); openSettings(app)
        app.buttons["play-style-classic"].tap()
        app.buttons["play-style-sandbox"].tap()
        let advance = app.buttons["sandboxAdvance"]; scrollTo(advance,in: app); advance.tap()
        let back = app.buttons["returnFormal"]; scrollTo(back,in: app); back.tap()
        app.navigationBars.buttons["完成"].tap()
        let probe = app.staticTexts["gameStateProbe"]
        XCTAssertTrue(waitFor(probe,containing: "style=classic;offset=0;egg=false;slots=2",timeout: 5))
        XCTAssertTrue(probe.label.contains("meals=0;weight=20;"))
        XCTAssertFalse(app.buttons["action-FOOD"].isEnabled)
    }
    func testDeviceCollectionCreatesAndSwitchesIndependentPets() throws {
        let app = launch()
        app.buttons["action-DIGIVICE"].tap()
        app.buttons["profile-dmc-ver1"].tap()
        XCTAssertTrue(app.buttons["create-device-dmc-ver1"].waitForExistence(timeout: 5))
        app.buttons["create-device-dmc-ver1"].tap()
        let old = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@","switch-slot-")).firstMatch
        XCTAssertTrue(old.waitForExistence(timeout: 5)); old.tap()
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["gameStateProbe"],containing: "egg=false;slots=2",timeout: 5))
        attachScreenshot("device-collection-returned-pet")
    }
    func testResetRequiresConfirmationAndPreservesOtherSlots() throws {
        let app = launch(); openSettings(app)
        let reset = app.buttons["resetDevice"]; scrollTo(reset,in: app); reset.tap()
        XCTAssertTrue(app.buttons["确认重置"].waitForExistence(timeout: 5))
        let cancel = app.buttons["取消"].exists ? app.buttons["取消"] : app.buttons["Cancel"]
        cancel.tap(); app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains("egg=false;"))
        openSettings(app); scrollTo(reset,in: app); reset.tap()
        XCTAssertTrue(app.buttons["确认重置"].waitForExistence(timeout: 5)); app.buttons["确认重置"].tap()
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["gameStateProbe"],containing: "egg=true;",timeout: 5))
    }
    func testLegacyProfileCanStillBeBackedUpAndRestored() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing","--ui-testing-legacy"]; app.launch()
        let settings = app.buttons["action-SETTINGS"]; scrollTo(settings,in: app); settings.tap()
        let start = app.buttons["备份旧档并开始 Ver.1"]; scrollTo(start,in: app); start.tap()
        XCTAssertTrue(app.buttons["hardware-A"].waitForExistence(timeout: 5))
        openSettings(app)
        let restore = app.buttons["restorePreviousProfile"]; scrollTo(restore,in: app); restore.tap()
        XCTAssertTrue(app.staticTexts["AGUMON"].waitForExistence(timeout: 5))
        attachScreenshot("legacy-profile-preserved")
    }
    func testDeveloperCodeAndSessionLock() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        openDeveloper(app)
        let code = app.secureTextFields["developerCode"]
        code.tap(); code.typeText("0000")
        app.buttons["developerUnlock"].tap()
        XCTAssertTrue(app.staticTexts["developerError"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["developerError"].label,"访问码不正确")
        XCTAssertFalse(app.buttons["developer-tab-species"].exists)
        code.tap(); code.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count: 4)+"0313")
        app.buttons["developerUnlock"].tap()
        XCTAssertTrue(app.buttons["developer-tab-species"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.secureTextFields["developerCode"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["developer-tab-species"].exists)
        app.navigationBars.buttons["完成"].tap()
        openDeveloper(app)
        XCTAssertTrue(app.secureTextFields["developerCode"].exists)
    }
    func testDeveloperSpeciesItemsStatsAndBackup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        openDeveloper(app)
        app.secureTextFields["developerCode"].tap()
        app.secureTextFields["developerCode"].typeText("0313")
        app.buttons["developerUnlock"].tap()
        XCTAssertTrue(app.buttons["developer-tab-species"].waitForExistence(timeout: 5))
        let search = app.textFields["developerSearch"]
        search.tap(); search.typeText("blitzgreymon"); dismissKeyboard(app)
        app.buttons["developer-species-blitzgreymon"].tap()
        XCTAssertEqual(app.staticTexts["developerNotice"].label,"已指定 电光暴龙兽")
        app.buttons["developer-tab-items"].tap()
        search.tap(); search.typeText("evolution-chip"); dismissKeyboard(app)
        app.buttons["developer-item-evolution-chip"].tap()
        XCTAssertEqual(app.buttons["developer-item-evolution-chip"].value as? String,"已选择")
        XCTAssertEqual(app.textFields["developerItemID"].value as? String,"evolution-chip")
        replaceText(app.textFields["developerItemQuantity"],with: "8")
        dismissKeyboard(app)
        app.buttons["developerGrantItem"].tap()
        XCTAssertEqual(app.staticTexts["developerNotice"].label,"已发放 8 × evolution-chip")
        let stats = app.buttons["developer-tab-stats"]
        if !stats.isHittable { app.swipeDown() }
        stats.tap()
        search.tap(); search.typeText("power"); dismissKeyboard(app)
        replaceText(app.textFields["developer-field-power"],with: "500")
        dismissKeyboard(app)
        app.buttons["developerSaveStats"].tap()
        XCTAssertEqual(app.staticTexts["developerNotice"].label,"数值已保存")
        XCTAssertEqual(app.textFields["developer-field-power"].value as? String,"500")
        attachScreenshot("developer-stats")
        app.buttons["developer-tab-backup"].tap()
        app.buttons["developerRestore"].tap()
        XCTAssertEqual(app.staticTexts["developerNotice"].label,"已恢复调试前存档")
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["亚古兽"].waitForExistence(timeout: 5))
    }
    func testLargeHomePetActuallyWalksAndTurns() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        let probe = app.staticTexts["homeMotionProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        XCTAssertTrue(probe.label.contains("size=192"))
        XCTAssertTrue(app.staticTexts["gameStateProbe"].label.contains("font=true"))
        XCTAssertTrue(waitFor(probe,containing: "pose=walk",timeout: 5))
        let before = probe.label.components(separatedBy: ";").first!
        attachScreenshot("large-pet-walk-a")
        let moved = NSPredicate { _,_ in !probe.label.hasPrefix(before+";") }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: moved,evaluatedWith: probe)],timeout: 4),.completed)
        attachScreenshot("large-pet-walk-b")
        XCTAssertTrue(waitFor(probe,containing: "right=false",timeout: 7))
        XCTAssertTrue(waitFor(probe,containing: "pose=happy",timeout: 12))
        attachScreenshot("large-pet-happy")
    }
    func testQuestPlaysEveryEnemyWithAttackEvasionHitAndResult() throws {
        let app = launch(quest: true)
        app.buttons["action-BATTLE"].tap(); app.buttons["lcdQuestStart"].tap()
        let probe = app.staticTexts["questAnimationProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 5))
        for battle in 1...3 {
            XCTAssertTrue(waitFor(app.staticTexts["questBattleNumber"],containing: "\(battle)/3",timeout: 22))
            XCTAssertTrue(waitFor(probe,containing: "shot=true",timeout: 8))
            attachScreenshot("lcd-quest-\(battle)-attack")
            XCTAssertTrue(waitFor(probe,containing: "mark=true",timeout: 4))
            attachScreenshot("lcd-quest-\(battle)-hit")
            XCTAssertTrue(waitFor(probe,containing: "回避",timeout: 8))
            XCTAssertTrue(waitFor(probe,containing: "pose=victory",timeout: 20))
        }
        XCTAssertTrue(app.buttons["lcdQuestReturn"].waitForExistence(timeout: 5))
        attachScreenshot("lcd-area-clear")
        app.buttons["lcdQuestReturn"].tap()
    }
    func testDigidexSearchAndAnimatedPreview() throws {
        let app = launch()
        app.buttons["action-DIGIDEX"].tap()
        let field = app.textFields["搜索名称 / ID"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Agumon")
        let row = app.buttons.containing(.staticText,identifier: "Agumon").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(element(app,"animationPreview").waitForExistence(timeout: 5))
        attachScreenshot("digidex-animated-preview")
    }
    private func launch(hatched: Bool = true,quest: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]
        if hatched { app.launchArguments.append("--ui-testing-hatched") }
        if quest { app.launchArguments.append("--ui-testing-quest") }
        app.launch()
        if hatched { XCTAssertTrue(app.buttons["hardware-A"].waitForExistence(timeout: 10)) }
        return app
    }
    private func element(_ app: XCUIApplication,_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func openSettings(_ app: XCUIApplication) {
        let settings = app.buttons["action-SETTINGS"]
        scrollTo(settings,in: app); settings.tap()
        XCTAssertTrue(app.buttons["play-style-classic"].waitForExistence(timeout: 5))
    }
    private func scrollTo(_ element: XCUIElement,in app: XCUIApplication) {
        for _ in 0..<10 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists)
    }
    private func waitFor(_ element: XCUIElement,containing text: String,timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.label.contains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
    private func openDeveloper(_ app: XCUIApplication) {
        let entry = app.descendants(matching: .any).matching(identifier: "developer-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<3 { if entry.isHittable { break }; app.swipeDown() }
        entry.press(forDuration: 2.2)
        XCTAssertTrue(app.secureTextFields["developerCode"].waitForExistence(timeout: 5))
    }
    private func replaceText(_ field: XCUIElement,with value: String) {
        let current = field.value as? String ?? ""
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count: current.count)+value)
    }
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.buttons["收起键盘"].exists { app.buttons["收起键盘"].tap() }
    }
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
