import XCTest

final class KeyboardInteractionTests: XCTestCase {
    @MainActor
    func testTypingHoldClipboardAndSettings() throws {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["Open keyboard test"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        if !open.isHittable { app.swipeUp() }
        open.tap()
        let text = app.textViews["Keyboard test text"]
        XCTAssertTrue(text.waitForExistence(timeout: 10), "The keyboard test must not crash while laying out its rows.")
        app.buttons["q"].tap()
        XCTAssertEqual(text.value as? String, "q")
        app.buttons["q"].press(forDuration: 0.6)
        XCTAssertEqual(text.value as? String, "q+", "Holding must commit one alternate without an extra q.")
        app.buttons["Delete"].tap()
        XCTAssertEqual(text.value as? String, "q")
        app.buttons["1"].tap()
        app.buttons["2"].tap()
        app.buttons["3"].tap()
        XCTAssertEqual(text.value as? String, "q123")
        app.buttons["Copy test text"].tap()
        app.buttons["Clipboard"].tap()
        let saved = app.buttons["q123"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "Copied text should automatically appear in clipboard history.")
        saved.tap()
        XCTAssertEqual(text.value as? String, "q123q123")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Haptics"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Back to keyboard").firstMatch.tap()
        XCTAssertTrue(app.buttons["q"].exists)
        app.buttons["Clear test text"].tap()
        app.buttons["t"].press(forDuration: 0.05, thenDragTo: app.buttons["o"])
        XCTAssertEqual(text.value as? String, "to ", "A continuous letter gesture should decode and insert a word.")
        app.buttons["!#1"].tap()
        XCTAssertTrue(app.buttons["@"].exists)
        XCTAssertFalse(app.buttons["Emoji"].exists)
        XCTAssertFalse(app.buttons["Cursor"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
        XCTAssertFalse(app.buttons["Hide keyboard"].exists)
    }
}
