import Foundation

/// Kept separately from history so deletion or eviction does not re-import a screenshot.
public struct ScreenshotCheckpoint: Codable, Sendable {
    public private(set) var date: Date
    public private(set) var identifiers: Set<String>
    public init(startingAt date: Date) { self.date = date; identifiers = [] }
    public func shouldImport(id: String, createdAt: Date) -> Bool {
        createdAt > date || (createdAt == date && !identifiers.contains(id))
    }
    public mutating func record(id: String, createdAt: Date) {
        if createdAt > date { date = createdAt; identifiers = [id] }
        else if createdAt == date { identifiers.insert(id) }
    }
}
