import Foundation
import Testing
@testable import ClipboardCore

struct ClipboardCaptureTests {
    @Test func screenshotCatchupKeepsIdsAcrossReopen() throws {
        let start = Date(timeIntervalSince1970: 100)
        var checkpoint = ScreenshotCheckpoint(startingAt: start)
        let next = start.addingTimeInterval(1)
        #expect(!checkpoint.shouldImport(id: "old", createdAt: start.addingTimeInterval(-1)))
        #expect(checkpoint.shouldImport(id: "new", createdAt: next))
        checkpoint.record(id: "new", createdAt: next)
        let restored = try JSONDecoder().decode(ScreenshotCheckpoint.self, from: JSONEncoder().encode(checkpoint))
        #expect(!restored.shouldImport(id: "new", createdAt: next))
        #expect(restored.shouldImport(id: "other", createdAt: next))
    }
    @Test func deniedReadIsNotRepeatedByTimerButCanRetryOnNextOpen() {
        var state = ClipboardCaptureState()
        #expect(state.shouldRead(change: 10, automaticSaving: true))
        state.willRead(change: 10)
        #expect(!state.shouldRead(change: 10, automaticSaving: true))
        state.beginPresentation()
        #expect(state.shouldRead(change: 10, automaticSaving: true))
        state.willRead(change: 10); state.didSave(change: 10)
        state.beginPresentation()
        #expect(!state.shouldRead(change: 10, automaticSaving: true))
    }
    @Test func changedClipboardIsSavedAndOwnWritesAreNotImportedAgain() {
        var state = ClipboardCaptureState(lastSavedChange: 3)
        #expect(!state.shouldRead(change: 3, automaticSaving: true))
        #expect(state.shouldRead(change: 4, automaticSaving: true))
        state.didSave(change: 4)
        #expect(!state.shouldRead(change: 4, automaticSaving: true))
        #expect(ClipboardCaptureState(lastSavedChange: state.lastSavedChange).shouldRead(change: 5, automaticSaving: true))
    }
    @Test func pausePreventsAutomaticReadsButAllowsExplicitRetry() {
        var state = ClipboardCaptureState()
        #expect(!state.shouldRead(change: 1, automaticSaving: false))
        #expect(state.shouldRead(change: 1, automaticSaving: false, force: true))
        state.willRead(change: 1)
        #expect(state.shouldRead(change: 1, automaticSaving: true, force: true))
    }
}
