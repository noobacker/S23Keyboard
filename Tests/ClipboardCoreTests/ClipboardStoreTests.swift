import Foundation
import Testing
@testable import ClipboardCore

final class ClipboardStoreTests {
    private let folder: URL
    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: folder) }

    @Test func fiftyFirstCopyPreservesEveryExistingItem() throws {
        let store = try ClipboardStore(directory: folder)
        for index in 1...50 { try store.add(text: "clip \(index)") }
        let oldIDs = Set(store.clips.map(\.id))
        #expect(throws: ClipboardError.full) { try store.add(text: "clip 51") }
        #expect(store.clips.count == 50)
        #expect(store.clips.first?.text == "clip 50")
        #expect(store.clips.last?.text == "clip 1")
        #expect(Set(store.clips.map(\.id)) == oldIDs)
    }

    @Test func textAndImageSurviveRelaunchWithoutExpiry() throws {
        let store = try ClipboardStore(directory: folder)
        let ancient = Date(timeIntervalSince1970: 1)
        try store.add(text: "hello 🌍\nsecond line", date: ancient)
        let bytes = Data([137, 80, 78, 71, 1, 2, 3])
        let image = try store.add(png: bytes, date: ancient)
        let reopened = try ClipboardStore(directory: folder)
        #expect(reopened.clips == store.clips)
        #expect(try reopened.imageData(for: image) == bytes)
        #expect(reopened.clips.last?.text == "hello 🌍\nsecond line")
    }

    @Test func fullMixedHistoryPreservesImagesAndRejectsNewPayload() throws {
        let store = try ClipboardStore(directory: folder)
        let old = try store.add(png: Data([1]))
        let retained = try store.add(png: Data([2]))
        let unrelated = folder.appendingPathComponent("keep.txt")
        try Data([3]).write(to: unrelated)
        for index in 0..<48 { try store.add(text: "\(index)") }
        #expect(throws: ClipboardError.full) { try store.add(png: Data([4])) }
        #expect(try store.imageData(for: old) == Data([1]))
        #expect(try store.imageData(for: retained) == Data([2]))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @Test func deleteIsPersistentAndPrunesImage() throws {
        let store = try ClipboardStore(directory: folder)
        let text = try store.add(text: "keep")
        let image = try store.add(png: Data([1, 2]))
        try store.remove(id: image.id)
        #expect(try ClipboardStore(directory: folder).clips == [text])
        #expect(throws: (any Error).self) { try store.imageData(for: image) }
    }

    @Test func clearIsPersistent() throws {
        let store = try ClipboardStore(directory: folder)
        try store.add(text: "one")
        let image = try store.add(png: Data([1]))
        try store.removeAll()
        #expect(try ClipboardStore(directory: folder).clips.isEmpty)
        #expect(throws: (any Error).self) { try store.imageData(for: image) }
    }

    @Test func emptyAndOversizedItemsLeaveHistoryUnchanged() throws {
        let store = try ClipboardStore(directory: folder)
        let original = try store.add(text: "keep")
        #expect(throws: ClipboardError.self) { try store.add(text: "") }
        #expect(throws: ClipboardError.self) { try store.add(png: Data()) }
        #expect(throws: ClipboardError.self) { try store.add(png: Data(repeating: 1, count: ClipboardStore.maximumBytes + 1)) }
        #expect(throws: ClipboardError.self) { try store.add(text: String(repeating: "é", count: ClipboardStore.maximumBytes / 2 + 1)) }
        #expect(store.clips == [original])
    }

    @Test func corruptManifestPreservedInsteadOfReset() throws {
        let url = folder.appendingPathComponent("history.json")
        let data = Data("corrupt but preserve".utf8)
        try data.write(to: url)
        #expect(throws: (any Error).self) { try ClipboardStore(directory: folder) }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test func failedCommitKeepsPriorHistoryAndPayload() throws {
        let store = try ClipboardStore(directory: folder)
        let image = try store.add(png: Data([1]))
        let url = folder.appendingPathComponent("history.json")
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try store.add(text: "cannot commit") }
        #expect(throws: (any Error).self) { try store.add(png: Data([2])) }
        #expect(throws: (any Error).self) { try store.removeAll() }
        #expect(store.clips == [image])
        #expect(try store.imageData(for: image) == Data([1]))
        let pngs = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".png") }
        #expect(pngs.count == 1)
    }

    @Test func noDeduplicationEveryCopyOccupiesOneSlot() throws {
        let store = try ClipboardStore(directory: folder)
        try store.add(text: "same")
        try store.add(text: "same")
        #expect(store.clips.count == 2)
        #expect(store.clips[0].id != store.clips[1].id)
    }

    @Test func unsafeImagePathIsRejectedWithoutTouchingFiles() throws {
        let id = UUID()
        let json = "[{\"id\":\"\(id)\",\"kind\":\"image\",\"createdAt\":0,\"imageFile\":\"../secret.png\"}]"
        let url = folder.appendingPathComponent("history.json")
        try Data(json.utf8).write(to: url)
        #expect(throws: ClipboardError.self) { try ClipboardStore(directory: folder) }
        #expect(try String(contentsOf: url, encoding: .utf8) == json)
    }

    @Test func upgradeReadsVersionOneHistoryWithoutRewritingOrDroppingItems() throws {
        let id = UUID()
        let json = "[{\"id\":\"\(id)\",\"kind\":\"text\",\"createdAt\":0,\"text\":\"saved before update\"}]"
        let url = folder.appendingPathComponent("history.json")
        try Data(json.utf8).write(to: url)
        let upgraded = try ClipboardStore(directory: folder)
        #expect(upgraded.clips.count == 1)
        #expect(upgraded.clips.first?.id == id)
        #expect(upgraded.clips.first?.text == "saved before update")
        #expect(try String(contentsOf: url, encoding: .utf8) == json)
    }

    @Test func screenshotRetryDoesNotConsumeAnotherSlot() throws {
        let store = try ClipboardStore(directory: folder)
        let first = try store.add(png: Data([1]), sourceIdentifier: "screenshot-1")
        let retry = try store.add(png: Data([1]), sourceIdentifier: "screenshot-1")
        #expect(first == retry)
        #expect(store.clips.count == 1)
        let reopened = try ClipboardStore(directory: folder)
        #expect(try reopened.add(png: Data([1]), sourceIdentifier: "screenshot-1") == first)
        #expect(reopened.clips.count == 1)
        try reopened.add(png: Data([1]))
        #expect(reopened.clips.count == 2)
    }
}
