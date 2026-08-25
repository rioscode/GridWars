import XCTest

final class GridWarsPhysicalSmokeTests: XCTestCase {
    @MainActor
    func testPhysicalTouchAndLifecycleFlow() {
        continueAfterFailure = false

        let device = XCUIDevice.shared
        device.orientation = .landscapeRight

        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        recordScreenshot(named: "01-attract")

        let bomb = app.coordinate(withNormalizedOffset: CGVector(dx: 0.77, dy: 0.90))
        bomb.tap()
        Thread.sleep(forTimeInterval: 4)
        assertLandscapeScreen(named: "02-playing")

        drag(
            in: app,
            from: CGVector(dx: 0.38, dy: 0.62),
            to: CGVector(dx: 0.43, dy: 0.56)
        )
        drag(
            in: app,
            from: CGVector(dx: 0.62, dy: 0.62),
            to: CGVector(dx: 0.69, dy: 0.55)
        )
        bomb.tap()
        recordScreenshot(named: "03-touch-and-bomb")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.07)).tap()
        Thread.sleep(forTimeInterval: 1)
        recordScreenshot(named: "04-options")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.62)).tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        assertLandscapeScreen(named: "05-continued")

        device.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        Thread.sleep(forTimeInterval: 1)
        assertLandscapeScreen(named: "06-foreground")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        Thread.sleep(forTimeInterval: 1)
        assertLandscapeScreen(named: "07-cold-relaunch")
    }

    @MainActor
    private func drag(in app: XCUIApplication, from start: CGVector, to end: CGVector) {
        app.coordinate(withNormalizedOffset: start).press(
            forDuration: 0.15,
            thenDragTo: app.coordinate(withNormalizedOffset: end)
        )
    }

    @MainActor
    private func assertLandscapeScreen(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        XCTAssertGreaterThan(screenshot.image.size.width, screenshot.image.size.height)
        recordScreenshot(screenshot, named: name)
    }

    @MainActor
    private func recordScreenshot(named name: String) {
        recordScreenshot(XCUIScreen.main.screenshot(), named: name)
    }

    @MainActor
    private func recordScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
