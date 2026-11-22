public struct ClipboardCaptureState {
    public private(set) var lastSavedChange: Int?
    private var lastAttemptedChange: Int?
    public init(lastSavedChange: Int? = nil) { self.lastSavedChange = lastSavedChange }
    public mutating func beginPresentation() { lastAttemptedChange = nil }
    public func shouldRead(change: Int, automaticSaving: Bool, force: Bool = false) -> Bool {
        force || (automaticSaving && change != lastSavedChange && change != lastAttemptedChange)
    }
    public mutating func willRead(change: Int) { lastAttemptedChange = change }
    public mutating func didSave(change: Int) { lastSavedChange = change; lastAttemptedChange = change }
}
