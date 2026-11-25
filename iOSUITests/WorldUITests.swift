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
        let picker = app.buttons["displayModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        for mode in ["经典灰绿色 LCD","高级彩色","复古彩色"] {
            picker.tap()
            app.buttons[mode].tap()
            XCTAssertTrue(picker.label.contains(mode),"Display selection should reflect \(mode)")
            attachScreenshot(mode == "经典灰绿色 LCD" ? "lcd-preview" : mode == "高级彩色" ? "advanced-color-preview" : "retro-color-preview")
        }
    }
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
