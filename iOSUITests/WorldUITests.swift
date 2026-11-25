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
        XCTAssertTrue(app.buttons["trainingTap"].waitForExistence(timeout: 5))
        app.buttons["trainingTap"].tap()
        // Wait on UI interaction rather than asserting a timing-sensitive training score.
        app.buttons["结束本次训练"].tap()
        XCTAssertTrue(app.buttons["beginTraining"].exists)
        app.navigationBars.buttons["完成"].tap()
        if !app.buttons["action-SETTINGS"].isHittable { app.swipeUp() }
        app.buttons["action-SETTINGS"].tap()
        XCTAssertTrue(app.staticTexts["DISPLAY / 像素显示"].waitForExistence(timeout: 5))
        attachScreenshot("settings")
    }
    func testAdventureAndDigidex() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--ui-testing-hatched"]
        app.launch()
        XCTAssertTrue(app.buttons["action-ADVENTURE"].waitForExistence(timeout: 10))
        app.buttons["action-ADVENTURE"].tap()
        XCTAssertTrue(app.staticTexts["收集 3 枚数据碎片"].waitForExistence(timeout: 5))
        attachScreenshot("signal-garden")
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
        XCTAssertTrue(app.staticTexts["COLOR LAB"].waitForExistence(timeout: 10))
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
