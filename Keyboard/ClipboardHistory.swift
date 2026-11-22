import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Uses ClipKey's capture state and storage. Only watches while the keyboard is visible.
final class ClipboardHistory {
    private let defaults = UserDefaults.standard
    private(set) var store: ClipboardStore?
    private var state: ClipboardCaptureState
    private(set) var message = ""
    var clips: [Clip] { store?.clips ?? [] }
    var automatic: Bool {
        get { defaults.object(forKey: "autoSaveClips") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoSaveClips") }
    }
    init() {
        state = ClipboardCaptureState(lastSavedChange: defaults.object(forKey: "lastSavedClipboardChange") as? Int)
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            var directory = base.appendingPathComponent("S23Clipboard", isDirectory: true)
            store = try ClipboardStore(directory: directory)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            if !defaults.bool(forKey: "clipboardHistoryMigrated") {
                for text in (defaults.stringArray(forKey: "clips") ?? []).reversed() where !text.isEmpty { try store?.add(text: text) }
                defaults.set(true, forKey: "clipboardHistoryMigrated"); defaults.removeObject(forKey: "clips")
            }
        } catch { message = "History unavailable: \(error.localizedDescription)" }
    }
    func beginPresentation() { state.beginPresentation() }
    func remember(_ count: Int) { state.didSave(change: count); defaults.set(count, forKey: "lastSavedClipboardChange") }
    @discardableResult
    func capture(allowed: Bool, force: Bool = false) -> Bool {
        guard allowed, let store else { return false }
        let pasteboard = UIPasteboard.general; let count = pasteboard.changeCount
        guard state.shouldRead(change: count, automaticSaving: automatic, force: force) else { return false }
        state.willRead(change: count)
        do {
            if pasteboard.hasImages {
                guard let type = pasteboard.types.first(where: { UTType($0)?.conforms(to: .image) == true }),
                      let data = pasteboard.data(forPasteboardType: type), let png = try Self.thumbnail(data, maximum: 1600) else {
                    message = "Image not saved. Tap Save copied item to try again."; return false
                }
                try store.add(png: png)
            } else if pasteboard.hasStrings {
                guard let text = pasteboard.string, !text.isEmpty else {
                    message = "Pasting was not allowed. Tap Save copied item to try again."; return false
                }
                try store.add(text: text)
            } else if pasteboard.hasURLs, let url = pasteboard.url { try store.add(text: url.absoluteString) }
            else { remember(count); return false }
            remember(count); message = ""; return true
        } catch { message = error.localizedDescription; return false }
    }
    func remove(_ clip: Clip) {
        do { try store?.remove(id: clip.id); message = "" } catch { message = error.localizedDescription }
    }
    func clear() {
        do { try store?.removeAll(); message = "History cleared." } catch { message = error.localizedDescription }
    }
    func accept(_ providers: [NSItemProvider], completion: @escaping () -> Void) {
        guard let provider = providers.first else { return }
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else {
                    DispatchQueue.main.async { self?.message = error?.localizedDescription ?? "Image unavailable."; completion() }; return
                }
                let scale = min(1, 1600 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let png = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.pngData()
                DispatchQueue.main.async {
                    guard let self else { return }
                    do {
                        guard let png else { self.message = "Image unavailable."; completion(); return }
                        try self.store?.add(png: png); self.remember(UIPasteboard.general.changeCount); self.message = ""
                    } catch { self.message = error.localizedDescription }
                    completion()
                }
            }
        } else if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    do {
                        guard let text = object as? String else { self.message = error?.localizedDescription ?? "Text unavailable."; completion(); return }
                        try self.store?.add(text: text); self.remember(UIPasteboard.general.changeCount); self.message = ""
                    } catch { self.message = error.localizedDescription }
                    completion()
                }
            }
        } else if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    do {
                        guard let url = object as? URL else { self.message = error?.localizedDescription ?? "Link unavailable."; completion(); return }
                        try self.store?.add(text: url.absoluteString); self.remember(UIPasteboard.general.changeCount); self.message = ""
                    } catch { self.message = error.localizedDescription }
                    completion()
                }
            }
        }
    }
    static func thumbnail(_ data: Data, maximum: Int) throws -> Data? {
        guard data.count <= 16 * 1024 * 1024 else { throw ClipboardError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maximum,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}

final class ClipboardPasteReceiver: UIView {
    var receive: (([NSItemProvider]) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.image.identifier, UTType.plainText.identifier, UTType.url.identifier])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func paste(itemProviders: [NSItemProvider]) { receive?(itemProviders) }
}
