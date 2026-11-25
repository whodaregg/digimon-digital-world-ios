import XCTest

final class WorldUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testHatchingAndHardwareNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["startHatching"].waitForExistence(timeout: 10))
        app.buttons["startHatching"].tap()
        XCTAssertTrue(app.buttons["action-FOOD"].waitForExistence(timeout: 5))
        let b = app.buttons["hardware-B"]
        if !b.isHittable { app.swipeUp() }
        b.tap()
        XCTAssertTrue(app.navigationBars["时钟"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["完成"].tap()
        app.buttons["hardware-A"].tap()
        b.tap()
        XCTAssertTrue(app.navigationBars["伙伴状态"].waitForExistence(timeout: 5))
        attachScreenshot("hatching-status")
    }
    func testFeedingTrainingAndDisplaySettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        XCTAssertTrue(app.buttons["action-FOOD"].waitForExistence(timeout: 10))
        app.buttons["action-FOOD"].tap()
        XCTAssertTrue(app.buttons["feed-meat"].waitForExistence(timeout: 5))
        app.buttons["feed-meat"].tap()
        app.navigationBars.buttons["完成"].tap()
        app.buttons["action-TRAIN"].tap()
        app.buttons["beginTraining"].tap()
        XCTAssertTrue(app.buttons["training-B"].waitForExistence(timeout: 5))
        for key in ["B","B","B","A","A"] { app.buttons["training-"+key].tap() }
        XCTAssertTrue(app.staticTexts["命中 5 / 5 · 成功，力量＋1心"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["beginTraining"].exists)
        app.navigationBars.buttons["完成"].tap()
        if !app.buttons["action-SETTINGS"].isHittable { app.swipeUp() }
        app.buttons["action-SETTINGS"].tap()
        XCTAssertTrue(app.staticTexts["DISPLAY / 像素显示"].waitForExistence(timeout: 5))
        attachScreenshot("settings")
    }
    func testSequentialQuestAndDigidex() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        XCTAssertTrue(app.buttons["action-BATTLE"].waitForExistence(timeout: 10))
        app.buttons["action-BATTLE"].tap()
        XCTAssertTrue(app.staticTexts["按区域顺序挑战"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quest-area-1"].isEnabled)
        XCTAssertFalse(app.buttons["quest-area-2"].isEnabled)
        XCTAssertFalse(app.buttons["移动 arrow.up"].exists)
        attachScreenshot("ver1-quest-areas")
        app.buttons["quest-area-1"].tap()
        XCTAssertTrue(app.staticTexts["第 1 / 3 战"].waitForExistence(timeout: 5))
        for _ in 0..<3 {
            if app.buttons["显示本战结果"].exists { app.buttons["显示本战结果"].tap() }
            if app.buttons["继续下一战"].exists { app.buttons["继续下一战"].tap() }
            else { break }
        }
        XCTAssertTrue(app.buttons["返回区域选择"].waitForExistence(timeout: 5))
        attachScreenshot("ver1-quest-result")
        app.buttons["返回区域选择"].tap()
        app.navigationBars.buttons["完成"].tap()
        if !app.buttons["action-DIGIDEX"].isHittable { app.swipeUp() }
        app.buttons["action-DIGIDEX"].tap()
        XCTAssertTrue(app.textFields["搜索名称 / ID"].waitForExistence(timeout: 5))
        let field = app.textFields["搜索名称 / ID"]
        field.tap(); field.typeText("Agumon")
        XCTAssertTrue(app.buttons.containing(.staticText,identifier: "Agumon").firstMatch.waitForExistence(timeout: 5))
    }
    func testOriginalColorAndFreeDisplaySwitching() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        XCTAssertTrue(app.staticTexts["COLOR Ver.1"].waitForExistence(timeout: 10))
        attachScreenshot("original-color-home")
        if !app.buttons["action-SETTINGS"].isHittable { app.swipeUp() }
        app.buttons["action-SETTINGS"].tap()
        for mode in ["lcd","advanced","color"] {
            let choice = app.buttons["display-mode-\(mode)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            XCTAssertEqual(choice.value as? String,"已选择")
            attachScreenshot(mode == "lcd" ? "lcd-preview" : mode == "advanced" ? "advanced-color-preview" : "retro-color-preview")
        }
    }
    func testLegacyProfileCanBePreservedAndRestored() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-legacy"]
        app.launch()
        XCTAssertTrue(app.buttons["action-SETTINGS"].waitForExistence(timeout: 10))
        if !app.buttons["action-SETTINGS"].isHittable { app.swipeUp() }
        app.buttons["action-SETTINGS"].tap()
        let start = app.buttons["备份旧档并开始 Ver.1"]
        for _ in 0..<3 { if start.isHittable { break }; app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.staticTexts["COLOR Ver.1"].waitForExistence(timeout: 5))
        if !app.buttons["action-SETTINGS"].isHittable { app.swipeUp() }
        app.buttons["action-SETTINGS"].tap()
        let restore = app.buttons["restorePreviousProfile"]
        for _ in 0..<5 { if restore.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restore.exists)
        restore.tap()
        XCTAssertTrue(app.staticTexts["COLOR LAB"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AGUMON"].exists)
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
        XCTAssertTrue(app.staticTexts["AGUMON"].waitForExistence(timeout: 5))
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
