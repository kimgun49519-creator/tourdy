import XCTest

final class NavigationUITests: XCTestCase {
    func testSystemTabViewKeepsTheOriginalWebScreensAfterRepeatedSwitching() {
        let app = XCUIApplication()
        app.launch()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.buttons["홈"].waitForExistence(timeout: 60))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true AND enabled == true"), object: bar.buttons["홈"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        for _ in 0..<6 {
            for name in ["할 일", "대시보드", "여행", "설정", "홈"] { bar.buttons[name].tap() }
        }
        for (tab, heading) in [("할 일", "오늘 할 일"), ("대시보드", "날짜별 공부 시간"), ("설정", "타이머 설정"), ("홈", "공부 시작")] {
            bar.buttons[tab].tap()
            XCTAssertTrue(app.webViews.staticTexts[heading].firstMatch.waitForExistence(timeout: 10), "Missing web screen for " + tab)
            XCTAssertTrue(bar.buttons[tab].isSelected)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
