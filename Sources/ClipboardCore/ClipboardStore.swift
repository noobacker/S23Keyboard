import Foundation

public struct Clip: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, image }
    public let id: UUID
    public let kind: Kind
    public let createdAt: Date
    public let text: String?
    public let imageFile: String?
    public let sourceIdentifier: String?
}

public enum ClipboardError: Error, LocalizedError {
    case empty, tooLarge, invalidManifest

    public var errorDescription: String? {
        switch self {
        case .empty: "The clipboard contains no supported content."
        case .tooLarge: "This item is too large to save. The limit is 8 MB per item."
        case .invalidManifest: "History could not be read. Existing files were preserved."
        }
    }
}

/// A single keyboard process owns this store. Commit the index before pruning payloads.
public final class ClipboardStore {
    public static let capacity = 50
    public static let maximumBytes = 8 * 1024 * 1024
    public private(set) var clips: [Clip] = []
    private let directory: URL
    private let manifest: URL
    private let files = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        manifest = directory.appendingPathComponent("history.json")
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        if files.fileExists(atPath: manifest.path) {
            let data = try Data(contentsOf: manifest)
            let saved = try JSONDecoder().decode([Clip].self, from: data)
            guard saved.count <= Self.capacity,
                  Set(saved.map(\.id)).count == saved.count,
                  saved.allSatisfy({ clip in
                      switch clip.kind {
                      case .text: return clip.text != nil && clip.imageFile == nil
                      case .image: return clip.text == nil && clip.imageFile == "\(clip.id.uuidString).png"
                      }
                  }) else { throw ClipboardError.invalidManifest }
            clips = saved
        }
    }

    @discardableResult
    public func add(text: String, date: Date = Date()) throws -> Clip {
        guard !text.isEmpty else { throw ClipboardError.empty }
        guard text.utf8.count <= Self.maximumBytes else { throw ClipboardError.tooLarge }
        let clip = Clip(id: UUID(), kind: .text, createdAt: date, text: text, imageFile: nil, sourceIdentifier: nil)
        try commit(Array(([clip] + clips).prefix(Self.capacity)))
        return clip
    }

    @discardableResult
    public func add(png: Data, date: Date = Date(), sourceIdentifier: String? = nil) throws -> Clip {
        guard !png.isEmpty else { throw ClipboardError.empty }
        guard png.count <= Self.maximumBytes else { throw ClipboardError.tooLarge }
        if let sourceIdentifier, let existing = clips.first(where: { $0.sourceIdentifier == sourceIdentifier }) { return existing }
        let id = UUID()
        let name = "\(id.uuidString).png"
        let payload = directory.appendingPathComponent(name)
        try png.write(to: payload, options: .atomic)
        do {
            let clip = Clip(id: id, kind: .image, createdAt: date, text: nil, imageFile: name, sourceIdentifier: sourceIdentifier)
            try commit(Array(([clip] + clips).prefix(Self.capacity)))
            return clip
        } catch {
            try? files.removeItem(at: payload)
            throw error
        }
    }

    public func imageData(for clip: Clip) throws -> Data {
        guard clip.kind == .image, let name = clip.imageFile,
              name == "\(clip.id.uuidString).png" else { throw ClipboardError.invalidManifest }
        return try Data(contentsOf: directory.appendingPathComponent(name))
    }

    public func remove(id: UUID) throws { try commit(clips.filter { $0.id != id }) }
    public func removeAll() throws { try commit([]) }

    private func commit(_ next: [Clip]) throws {
        let data = try JSONEncoder().encode(next)
        try data.write(to: manifest, options: .atomic)
        clips = next
        // Only prune after a successful manifest write; never remove unrelated files.
        let retained = Set(next.compactMap(\.imageFile))
        if let contents = try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "png" && !retained.contains(url.lastPathComponent) {
                if UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil {
                    try? files.removeItem(at: url)
                }
            }
        }
    }
}
