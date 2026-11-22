import UIKit
import UniformTypeIdentifiers
import AVFoundation

final class ClickInputView: UIInputView, UIInputViewAudioFeedback {
    var typingKeys: [KeyButton] = []
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit is UIControl || hit?.superview is UIControl { return hit }
        guard bounds.contains(point), !typingKeys.isEmpty else { return hit }
        return typingKeys.filter { $0.convert($0.bounds, to: self).insetBy(dx: -10, dy: -10).contains(point) }
            .min { a, b in
                let ac = a.convert(CGPoint(x: a.bounds.midX, y: a.bounds.midY), to: self)
                let bc = b.convert(CGPoint(x: b.bounds.midX, y: b.bounds.midY), to: self)
                return hypot(ac.x - point.x, ac.y - point.y) < hypot(bc.x - point.x, bc.y - point.y)
            } ?? hit
    }
    var enableInputClicksWhenVisible: Bool { UserDefaults.standard.object(forKey: "sound") as? Bool ?? true }
}

// Native UIKit styling; iOS renders emoji with its own emoji font.
private enum KeyboardStyle {
    static let background = UIColor { $0.userInterfaceStyle == .dark
        ? .black : UIColor(red: 0.89, green: 0.90, blue: 0.92, alpha: 1) }
    static let key = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.224, alpha: 1) : .white }
    static let utility = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.09, alpha: 1) : UIColor(red: 0.76, green: 0.78, blue: 0.81, alpha: 1) }
    static let pressed = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.49, alpha: 1) : UIColor(red: 0.70, green: 0.75, blue: 0.83, alpha: 1) }
    static let secondary = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.8, alpha: 1) : UIColor(white: 0.25, alpha: 1) }
}

final class KeyButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -4, dy: -6).contains(point)
    }
    var highlightEnabled = true
    var previewText: String?
    var alternatives: [String] = []
    var suppressedTap = false
    var beganTouch: ((KeyButton) -> Void)?
    var endedTouch: (() -> Void)?
    var restingColor = KeyboardStyle.key { didSet { updateAppearance() } }
    override var isHighlighted: Bool { didSet { updateAppearance() } }
    private func updateAppearance() {
        backgroundColor = isHighlighted && highlightEnabled ? KeyboardStyle.pressed : restingColor
    }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        suppressedTap = false
        let result = super.beginTracking(touch, with: event)
        if result { beganTouch?(self) }; return result
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event); endedTouch?()
    }
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event); endedTouch?()
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let result = super.continueTracking(touch, with: event)
        if !suppressedTap && !bounds.insetBy(dx: -12, dy: -20).contains(touch.location(in: self)) { endedTouch?() }
        return result
    }
}

final class KeyboardViewController: UIInputViewController, UIGestureRecognizerDelegate {
    private let defaults = UserDefaults.standard
    private let root = UIStackView()
    private var heightConstraint: NSLayoutConstraint?
    private var shift = false
    private var capsLock = false
    private var symbols = false
    private var secondSymbols = false
    private var panel = "keys"
    private var deleteTimer: Timer?
    private var delayTimer: Timer?
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let history = ClipboardHistory()
    private var clipboardTimer: Timer?
    private var clipboardObserver: NSObjectProtocol?
    private var callout: UIView?
    private var alternateLabels: [UILabel] = []
    private var selectedAlternate = 0
    private var editingClips = false
    private var clipboardMessage = ""
    private var spaceOrigin: CGFloat = 0
    private var cursorOrigin = CGPoint.zero
    private var cursorOverlay: UIView?
    private var swipeSamples: [SwipePoint] = []
    private var swipeCenters: [String: SwipePoint] = [:]
    private var swipeCandidates: [String] = []
    private var lastSwipeWord = ""
    private var swipePendingCapital = false
    private var clickPlayer: AVAudioPlayer?
    private var letterButtons: [KeyButton] = []
    private var panelStack: UIStackView?
    private var landscape = false
    weak var testTextView: UITextView?
    private var clipboardAccess: Bool { testTextView != nil || hasFullAccess }
    private var highlights: Bool {
        defaults.object(forKey: "highlights") == nil || defaults.bool(forKey: "highlights")
    }
    private var keyHeight: CGFloat {
        let value = defaults.double(forKey: "keyHeight")
        return landscape ? 34 : min(58, max(40, value == 0 ? 47 : CGFloat(value)))
    }

    override func loadView() {
        let input = ClickInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true; view = input
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        defaults.register(defaults: ["haptics": true, "sound": true, "strength": 0.7, "keyPreview": true, "soundVolume": 0.7, "swipeTyping": true])
        applyTheme()
        configureClickSound()
        history.didChange = { [weak self] in
            guard let self, self.isViewLoaded else { return }
            if self.panel == "clipboard" || self.panel == "settings" { self.render() }
        }
        view.backgroundColor = KeyboardStyle.background
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -4)
        ])
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 360)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(swipeTyping(_:)))
        swipe.delegate = self; swipe.cancelsTouchesInView = true; view.addGestureRecognizer(swipe)
        render()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDeleting(); hideCallout(); clipboardTimer?.invalidate(); clipboardTimer = nil
        if let clipboardObserver { NotificationCenter.default.removeObserver(clipboardObserver) }; clipboardObserver = nil
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        impact.prepare(); history.beginPresentation(); captureClipboard()
        clipboardTimer?.invalidate()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.captureClipboard() }
        if let clipboardObserver { NotificationCenter.default.removeObserver(clipboardObserver) }
        clipboardObserver = NotificationCenter.default.addObserver(forName: UIPasteboard.changedNotification, object: nil, queue: .main) { [weak self] _ in self?.captureClipboard() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let value = view.bounds.width > 600
        if value != landscape { landscape = value; render() }
    }
    deinit {
        deleteTimer?.invalidate(); delayTimer?.invalidate(); clipboardTimer?.invalidate()
        if let clipboardObserver { NotificationCenter.default.removeObserver(clipboardObserver) }
    }
    private func captureClipboard(force: Bool = false) {
        let old = history.message
        let changed = history.capture(allowed: clipboardAccess, force: force)
        history.syncScreenshots(allowed: clipboardAccess)
        if panel == "clipboard" && (changed || old != history.message || force) { render() }
    }
    private func feedback() {
        if defaults.bool(forKey: "sound") {
            clickPlayer?.volume = defaults.float(forKey: "soundVolume")
            clickPlayer?.currentTime = 0; clickPlayer?.play()
        }
        if defaults.bool(forKey: "haptics") {
            let strength = defaults.double(forKey: "strength")
            impact.impactOccurred(intensity: min(1, max(0.1, strength)))
            impact.prepare()
        }
    }
    private func clearRoot() {
        stopDeleting(); hideCallout(); panelStack = nil; letterButtons = []
        (view as? ClickInputView)?.typingKeys = []
        root.arrangedSubviews.forEach { root.removeArrangedSubview($0); $0.removeFromSuperview() }
    }
    private func row(height: CGFloat) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.distribution = .fillEqually
        stack.heightAnchor.constraint(equalToConstant: height).isActive = true
        (panelStack ?? root).addArrangedSubview(stack)
        return stack
    }
    private func button(_ title: String, hint: String? = nil, action: @escaping () -> Void) -> KeyButton {
        let key = KeyButton(type: .custom)
        key.highlightEnabled = highlights
        key.restingColor = ["⇧", "⇪", "⌫", "!#1", "ABC", "↵", "Search", "Send", "Go", "Done"].contains(title)
            ? KeyboardStyle.utility : KeyboardStyle.key
        key.layer.cornerRadius = 8
        key.layer.shadowColor = UIColor.black.cgColor
        key.layer.shadowOpacity = 0
        key.layer.shadowOffset = CGSize(width: 0, height: 1)
        key.layer.shadowRadius = 0.5
        key.setTitle(title, for: .normal)
        key.setTitleColor(.label, for: .normal)
        key.titleLabel?.font = .systemFont(ofSize: title.count > 3 ? 14 : 26, weight: .regular)
        key.accessibilityLabel = title
        key.beganTouch = { [weak self] key in self?.feedback(); self?.showPreview(key) }
        key.endedTouch = { [weak self] in self?.hideCallout() }
        key.addAction(UIAction { [weak key] _ in guard key?.suppressedTap == false else { return }; action() }, for: .touchUpInside)
        if let hint = hint {
            let label = UILabel()
            label.text = hint
            label.textColor = KeyboardStyle.secondary
            label.font = .systemFont(ofSize: 9)
            label.translatesAutoresizingMaskIntoConstraints = false
            key.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: key.topAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: key.trailingAnchor, constant: -3)
            ])
            key.accessibilityHint = "Hold for \(hint)"
            key.alternatives = [hint]
        }
        let icon: KeyboardIcon?
        switch title {
        case "⇧": icon = .shift
        case "⇪": icon = .capsLock
        case "⌫": icon = .delete
        case "↵": icon = .enter
        case "⌄": icon = .dismiss
        case "←": icon = .left
        case "→": icon = .right
        default: icon = nil
        }
        if let icon { key.setTitle(nil, for: .normal); key.setImage(icon.image, for: .normal); key.tintColor = .label }
        return key
    }
    private func addHold(to key: KeyButton) {
        guard !key.alternatives.isEmpty else { return }
        let press = UILongPressGestureRecognizer(target: self, action: #selector(holdKey(_:)))
        press.minimumPressDuration = 0.35; press.cancelsTouchesInView = false; key.addGestureRecognizer(press)
        key.accessibilityHint = "Hold and slide for \(key.alternatives.joined(separator: ", "))"
        key.accessibilityCustomActions = key.alternatives.map { value in
            UIAccessibilityCustomAction(name: "Insert \(value)") { [weak self] _ in self?.insert(value); return true }
        }
    }
    private func showPreview(_ key: KeyButton) {
        hideCallout()
        guard defaults.bool(forKey: "keyPreview"), let text = key.previewText else { return }
        let frame = key.convert(key.bounds, to: view)
        let label = UILabel(); label.text = text; label.textAlignment = .center; label.font = .systemFont(ofSize: 34)
        label.textColor = .label; label.backgroundColor = KeyboardStyle.key; label.layer.cornerRadius = 9; label.clipsToBounds = true
        label.layer.borderWidth = 0.5; label.layer.borderColor = KeyboardStyle.secondary.cgColor
        label.frame = CGRect(x: min(view.bounds.width - 63, max(3, frame.midX - 30)), y: max(2, frame.minY - 58), width: 60, height: 56)
        label.isUserInteractionEnabled = false; label.isAccessibilityElement = false
        view.addSubview(label); callout = label
    }
    private func hideCallout() { callout?.removeFromSuperview(); callout = nil; alternateLabels = [] }
    @objc private func holdKey(_ gesture: UILongPressGestureRecognizer) {
        guard let key = gesture.view as? KeyButton else { return }
        switch gesture.state {
        case .began:
            key.suppressedTap = true; hideCallout(); feedback()
            let frame = key.convert(key.bounds, to: view)
            let width = min(view.bounds.width - 8, CGFloat(key.alternatives.count) * 38)
            let strip = UIStackView(); strip.axis = .horizontal; strip.distribution = .fillEqually
            strip.backgroundColor = KeyboardStyle.key; strip.layer.cornerRadius = 9; strip.clipsToBounds = true
            strip.layer.borderWidth = 0.5; strip.layer.borderColor = KeyboardStyle.secondary.cgColor
            strip.frame = CGRect(x: min(view.bounds.width - width - 4, max(4, frame.midX - width / 2)), y: max(2, frame.minY - 51), width: width, height: 48)
            for value in key.alternatives {
                let label = UILabel(); label.text = value; label.textColor = .label; label.font = .systemFont(ofSize: 24); label.textAlignment = .center
                strip.addArrangedSubview(label); alternateLabels.append(label)
            }
            strip.isUserInteractionEnabled = false; view.addSubview(strip); callout = strip; selectAlternate(0)
        case .changed:
            guard let callout else { return }
            let index = Int(gesture.location(in: callout).x / (callout.bounds.width / CGFloat(key.alternatives.count)))
            selectAlternate(min(key.alternatives.count - 1, max(0, index)))
        case .ended:
            let value = key.alternatives[min(selectedAlternate, key.alternatives.count - 1)]
            hideCallout(); insert(value)
        case .cancelled, .failed: hideCallout()
        default: break
        }
    }
    private func selectAlternate(_ index: Int) {
        if index != selectedAlternate { feedback() }; selectedAlternate = index
        for (position, label) in alternateLabels.enumerated() { label.backgroundColor = position == index ? KeyboardStyle.pressed : .clear }
    }
    private func insert(_ text: String) {
        lastSwipeWord = ""
        if let testTextView { testTextView.insertText(text) } else { textDocumentProxy.insertText(text) }
        if shift && !capsLock { shift = false; render() }
    }
    private func deleteCharacter() {
        if let testTextView { testTextView.deleteBackward() } else { textDocumentProxy.deleteBackward() }
    }
    private func moveCursor(_ offset: Int) {
        if let textView = testTextView, let range = textView.selectedTextRange,
           let position = textView.position(from: range.start, offset: offset) { textView.selectedTextRange = textView.textRange(from: position, to: position) }
        else if testTextView == nil { textDocumentProxy.adjustTextPosition(byCharacterOffset: offset) }
    }
    private func applyTheme() {
        switch defaults.string(forKey: "keyboardTheme") ?? "auto" {
        case "light": overrideUserInterfaceStyle = .light
        case "dark": overrideUserInterfaceStyle = .dark
        default: overrideUserInterfaceStyle = .unspecified
        }
    }
    private func configureClickSound() {
        // Original short mechanical click, synthesized locally; no Samsung recording.
        let rate = 22050, count = 800
        var samples = Data()
        for index in 0..<count {
            let time = Double(index) / Double(rate)
            let envelope = exp(-time * 240)
            let wave = sin(time * 2 * .pi * 1700) * 0.65 + sin(time * 2 * .pi * 3400) * 0.25
            var value = Int16(max(-32767, min(32767, wave * envelope * 22000))).littleEndian
            withUnsafeBytes(of: &value) { samples.append(contentsOf: $0) }
        }
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u32(_ value: UInt32) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + samples.count)); text("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16); text("data"); u32(UInt32(samples.count)); data.append(samples)
        clickPlayer = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
        clickPlayer?.prepareToPlay()
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard panel == "keys", !symbols, defaults.bool(forKey: "swipeTyping") else { return false }
        let point = touch.location(in: view)
        return letterButtons.contains { $0.convert($0.bounds, to: view).contains(point) }
    }
    @objc private func swipeTyping(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: view)
        let width = max(1, view.bounds.width)
        let sample = SwipePoint(x: Double(point.x / width), y: Double(point.y / width))
        if gesture.state == .began {
            hideCallout(); swipeSamples = []
            swipePendingCapital = shift
            swipeCenters = Dictionary(uniqueKeysWithValues: letterButtons.compactMap { key in
                guard let letter = key.previewText?.lowercased() else { return nil }
                let center = key.convert(CGPoint(x: key.bounds.midX, y: key.bounds.midY), to: view)
                return (letter, SwipePoint(x: Double(center.x / width), y: Double(center.y / width)))
            })
            let start = CGPoint(x: point.x - gesture.translation(in: view).x, y: point.y - gesture.translation(in: view).y)
            swipeSamples.append(SwipePoint(x: Double(start.x / width), y: Double(start.y / width)))
        }
        swipeSamples.append(sample)
        if gesture.state == .ended {
            swipeCandidates = SwipeDecoder().suggestions(for: swipeSamples, keyCenters: swipeCenters, limit: 3)
            if let word = swipeCandidates.first {
                let output = swipePendingCapital ? word.prefix(1).uppercased() + word.dropFirst() : word
                insert(output + " "); lastSwipeWord = output + " "; feedback(); render()
            }
        } else if gesture.state == .cancelled || gesture.state == .failed { swipeSamples = [] }
    }
    private func toolbar() {
        let bar = row(height: 44)
        for (title, icon, destination) in [("Clipboard", KeyboardIcon.clipboard, "clipboard"), ("Settings", .settings, "settings")] {
            let key = button(title) { [weak self] in
                guard let self else { return }; self.panel = self.panel == destination ? "keys" : destination
                if self.panel == "clipboard" { self.history.beginPresentation(); self.history.capture(allowed: self.clipboardAccess) }
                self.render()
            }
            var config = UIButton.Configuration.plain(); config.image = icon.image; config.title = title
            config.imagePlacement = .leading; config.imagePadding = 8; config.contentInsets = .zero
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes; attributes.font = .systemFont(ofSize: 14, weight: .medium); return attributes
            }
            config.baseForegroundColor = .label; key.configuration = config
            key.restingColor = panel == destination ? KeyboardStyle.utility : .clear
            key.layer.shadowOpacity = 0
            bar.addArrangedSubview(key)
        }
    }
    private func render() {
        clearRoot()
        heightConstraint?.constant = 5 * keyHeight + 146
        toolbar()
        if panel == "keys" {
            let suggestions = row(height: 28)
            for word in swipeCandidates.isEmpty ? ["I", "the", "and"] : swipeCandidates {
                let key = button(word) { [weak self] in
                    guard let self else { return }
                    if !self.lastSwipeWord.isEmpty { for _ in self.lastSwipeWord { self.deleteCharacter() } }
                    self.insert(word + " "); self.lastSwipeWord = ""
                }
                key.restingColor = .clear; key.titleLabel?.font = .systemFont(ofSize: 15); suggestions.addArrangedSubview(key)
            }
        }
        switch panel {
        case "settings": settingsPanel()
        case "clipboard": clipboardPanel()
        case "emoji": emojiPanel()
        case "cursor": cursorPanel()
        case "more": morePanel()
        default: keys()
        }
        panelStack = nil
    }
    private func keys() {
        let numbers = row(height: keyHeight - 8)
        for character in "1234567890" {
            let value = String(character)
            let key = button(value) { [weak self] in self?.insert(value) }
            key.previewText = value; key.titleLabel?.font = .systemFont(ofSize: 20); numbers.addArrangedSubview(key)
        }
        let letters = symbols
            ? (secondSymbols ? ["`~\\|{}€£¥$", "°•○●□■♤♡♢♧", "☆▪¤《》¡¿"] : ["+×÷=/_<>[]", "!@#₹%^&*()", "-'\":;,?"])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        let hints = [Array("+×÷=_<>[]"), Array("!@#£%&*()"), Array("-\"':;!?/")]
        let accents = ["a": ["à", "á", "â", "ä", "æ", "ã", "å"], "e": ["è", "é", "ê", "ë"], "i": ["ì", "í", "î", "ï"], "o": ["ò", "ó", "ô", "ö", "ø"], "u": ["ù", "ú", "û", "ü"], "c": ["ç"], "n": ["ñ"], "s": ["ß"]]
        for (index, line) in letters.enumerated() {
            let stack = row(height: keyHeight)
            stack.distribution = .fill
            var characterKeys: [UIView] = []
            if index == 1 && !symbols {
                let spacer = UIView(); stack.addArrangedSubview(spacer)
                spacer.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.035).isActive = true
            }
            if index == 2 {
                let key = button(symbols ? (secondSymbols ? "2/2" : "1/2") : (capsLock ? "⇪" : "⇧")) { [weak self] in
                    guard let self = self else { return }
                    if self.symbols { self.secondSymbols.toggle() }
                    else if self.shift { self.capsLock.toggle(); self.shift = self.capsLock }
                    else { self.shift = true }
                    self.render()
                }
                key.accessibilityLabel = symbols ? "More symbols" : "Shift; tap again for caps lock"
                if shift && !symbols { key.tintColor = .systemBlue }
                stack.addArrangedSubview(key)
                key.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.12).isActive = true
            }
            for (column, character) in line.enumerated() {
                let value = String(character)
                let output = !symbols && shift ? value.uppercased() : value
                let hint: String? = nil
                let key = button(output, hint: hint) { [weak self] in self?.insert(output) }
                key.previewText = output
                if !symbols { key.alternatives += (accents[value] ?? []).map { shift ? $0.uppercased() : $0 } }
                if !symbols && column < hints[index].count { key.alternatives.insert(String(hints[index][column]), at: 0) }
                addHold(to: key); stack.addArrangedSubview(key); characterKeys.append(key)
                if !symbols { letterButtons.append(key) }
            }
            if let first = characterKeys.first {
                for key in characterKeys.dropFirst() { key.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true }
            }
            if index == 1 && !symbols {
                let spacer = UIView(); stack.addArrangedSubview(spacer)
                spacer.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.035).isActive = true
            }
            if index == 2 {
                let delete = button("⌫") { [weak self] in self?.deleteCharacter() }
                delete.accessibilityLabel = "Delete"
                delete.addTarget(self, action: #selector(startDeleting(_:)), for: .touchDown)
                delete.addTarget(self, action: #selector(stopDeleting), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
                stack.addArrangedSubview(delete)
                delete.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.12).isActive = true
            }
        }
        let bottom = row(height: keyHeight)
        bottom.distribution = .fill
        bottom.addArrangedSubview(button(symbols ? "ABC" : "!#1") { [weak self] in self?.symbols.toggle(); self?.render() })
        bottom.addArrangedSubview(button(",") { [weak self] in self?.insert(",") })
        let space = button("English(India)") { [weak self] in self?.insert(" ") }
        space.accessibilityLabel = "Space"
        space.accessibilityHint = "Hold and slide to move the cursor"
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdSpace(_:)))
        hold.minimumPressDuration = 0.3; space.addGestureRecognizer(hold)
        bottom.addArrangedSubview(space)
        bottom.addArrangedSubview(button(".") { [weak self] in self?.insert(".") })
        let returnLabel: String
        switch testTextView == nil ? (textDocumentProxy.returnKeyType ?? .default) : .default {
        case .search: returnLabel = "Search"
        case .send: returnLabel = "Send"
        case .go: returnLabel = "Go"
        case .done: returnLabel = "Done"
        default: returnLabel = "↵"
        }
        bottom.addArrangedSubview(button(returnLabel) { [weak self] in self?.insert("\n") })
        for key in bottom.arrangedSubviews where key !== space {
            key.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.12).isActive = true
        }
        func collect(_ view: UIView) -> [KeyButton] {
            if let key = view as? KeyButton { return [key] }
            return view.subviews.flatMap(collect)
        }
        (view as? ClickInputView)?.typingKeys = root.arrangedSubviews.dropFirst(2).flatMap(collect)
    }
    @objc private func holdSpace(_ gesture: UILongPressGestureRecognizer) {
        guard let key = gesture.view as? KeyButton else { return }
        if gesture.state == .began {
            key.suppressedTap = true; cursorOrigin = gesture.location(in: view)
            feedback(); showCursorOverlay()
        } else if gesture.state == .changed {
            let point = gesture.location(in: view)
            let horizontal = Int((point.x - cursorOrigin.x) / 9)
            let vertical = Int((point.y - cursorOrigin.y) / 24)
            if vertical != 0 { moveVertical(vertical); cursorOrigin.y += CGFloat(vertical) * 24 }
            if horizontal != 0 { moveCursor(horizontal); cursorOrigin.x += CGFloat(horizontal) * 9 }
        } else if [.ended, .cancelled, .failed].contains(gesture.state) {
            cursorOverlay?.removeFromSuperview(); cursorOverlay = nil
        }
    }
    private func showCursorOverlay() {
        let overlay = UIView(frame: view.bounds); overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.75); overlay.isUserInteractionEnabled = false
        let label = UILabel(); label.text = "↕  ↔\nCursor control"; label.numberOfLines = 2; label.textAlignment = .center
        label.textColor = .white; label.font = .systemFont(ofSize: 22, weight: .medium); label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label); NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor), label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)])
        view.addSubview(overlay); cursorOverlay = overlay
    }
    private func moveVertical(_ lines: Int) {
        if let textView = testTextView, let selected = textView.selectedTextRange {
            let rect = textView.caretRect(for: selected.start)
            let point = CGPoint(x: rect.midX, y: rect.midY + CGFloat(lines) * (textView.font?.lineHeight ?? 24))
            if let position = textView.closestPosition(to: point) { textView.selectedTextRange = textView.textRange(from: position, to: position) }
            return
        }
        // The host exposes context, not screen coordinates: preserve the logical line column.
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let column = before.split(separator: "\n", omittingEmptySubsequences: false).last?.count ?? 0
        if lines < 0 {
            let previous = before.split(separator: "\n", omittingEmptySubsequences: false)
            guard previous.count > 1 else { return }
            let length = previous[previous.count - 2].count
            moveCursor(-(column + 1 + length - min(column, length)))
        } else {
            let next = after.split(separator: "\n", omittingEmptySubsequences: false)
            guard next.count > 1 else { return }
            moveCursor(next[0].count + 1 + min(column, next[1].count))
        }
    }
    @objc private func startDeleting(_ key: KeyButton) {
        stopDeleting()
        delayTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self, weak key] _ in
            key?.suppressedTap = true; self?.deleteCharacter(); self?.feedback()
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
                self?.deleteCharacter()
            }
        }
    }
    @objc private func stopDeleting() {
        delayTimer?.invalidate(); deleteTimer?.invalidate()
        delayTimer = nil; deleteTimer = nil
    }
    private func note(_ text: String) {
        let label = UILabel(); label.text = text; label.numberOfLines = 0
        label.textColor = KeyboardStyle.secondary; label.font = .systemFont(ofSize: 13)
        (panelStack ?? root).addArrangedSubview(label)
    }
    private func back() {
        row(height: 36).addArrangedSubview(button("Back to keyboard") { [weak self] in self?.panel = "keys"; self?.render() })
    }
    private func toggle(_ title: String, key: String, value: Bool) {
        let stack = row(height: 34)
        let label = UILabel(); label.text = title; label.textColor = .label
        let control = UISwitch(); control.isOn = value
        control.accessibilityLabel = title
        control.addAction(UIAction { [weak self, weak control] _ in
            self?.defaults.set(control?.isOn ?? false, forKey: key)
            if key == "haptics" { self?.feedback() }
            if key == "autoSaveClips" { self?.captureClipboard() }
            if key == "screenshotSaving" { self?.history.setScreenshotSaving(control?.isOn ?? false) }
        }, for: .valueChanged)
        stack.distribution = .fill; stack.addArrangedSubview(label); stack.addArrangedSubview(control)
    }
    private func slider(_ title: String, key: String, value: Float, range: ClosedRange<Float>) {
        note(title)
        let control = UISlider(); control.minimumValue = range.lowerBound; control.maximumValue = range.upperBound; control.value = value
        control.addAction(UIAction { [weak self, weak control] _ in self?.defaults.set(control?.value ?? value, forKey: key) }, for: .valueChanged)
        control.accessibilityLabel = title
        control.addAction(UIAction { [weak self] _ in
            if key == "keyHeight" { self?.render() } else { self?.feedback() }
        }, for: [.touchUpInside, .touchUpOutside])
        (panelStack ?? root).addArrangedSubview(control)
    }
    private func beginScrollablePanel() {
        let scroll = UIScrollView(); scroll.alwaysBounceVertical = true
        scroll.heightAnchor.constraint(equalToConstant: 5 * keyHeight + 32).isActive = true
        root.addArrangedSubview(scroll)
        let list = UIStackView(); list.axis = .vertical; list.spacing = 8; list.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20), list.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            list.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        panelStack = list
    }
    private func settingsPanel() {
        beginScrollablePanel()
        note("Appearance")
        let appearance = UISegmentedControl(items: ["Light", "Dark", "Auto"])
        appearance.selectedSegmentIndex = ["light", "dark", "auto"].firstIndex(of: defaults.string(forKey: "keyboardTheme") ?? "auto") ?? 2
        appearance.accessibilityLabel = "Keyboard appearance"
        appearance.addAction(UIAction { [weak self, weak appearance] _ in
            guard let self, let index = appearance?.selectedSegmentIndex else { return }
            self.defaults.set(["light", "dark", "auto"][index], forKey: "keyboardTheme"); self.applyTheme(); self.render()
        }, for: .valueChanged)
        panelStack?.addArrangedSubview(appearance)
        if !clipboardAccess { note("Allow Full Access in iPhone Settings for clipboard capture and keyboard haptics. This build has no network service.") }
        toggle("Tap highlight", key: "highlights", value: highlights)
        toggle("Character preview", key: "keyPreview", value: defaults.bool(forKey: "keyPreview"))
        toggle("Key sound", key: "sound", value: defaults.bool(forKey: "sound"))
        toggle("Haptics", key: "haptics", value: defaults.bool(forKey: "haptics"))
        toggle("Auto-save copied items", key: "autoSaveClips", value: history.automatic)
        toggle("Swipe to type", key: "swipeTyping", value: defaults.bool(forKey: "swipeTyping"))
        toggle("Save screenshots", key: "screenshotSaving", value: defaults.bool(forKey: "screenshotSaving"))
        note("Screenshots import while this keyboard is visible, after Photos access is granted. iOS does not permit clipboard monitoring while the keyboard is closed.")
        slider("Click volume", key: "soundVolume", value: defaults.float(forKey: "soundVolume"), range: 0...1)
        slider("Haptic strength", key: "strength", value: defaults.object(forKey: "strength") == nil ? 0.5 : defaults.float(forKey: "strength"), range: 0.1...1)
        slider("Key height", key: "keyHeight", value: Float(keyHeight), range: 40...58)
        row(height: 44).addArrangedSubview(button("Test feedback") { [weak self] in self?.feedback() })
        back()
    }
    private func clipboardPanel() {
        beginScrollablePanel()
        let header = row(height: 36); header.distribution = .fill
        let title = UILabel(); title.text = "Clipboard · \(history.clips.count)/50"; title.textColor = .label
        title.font = .systemFont(ofSize: 16, weight: .semibold); header.addArrangedSubview(title)
        let edit = button(editingClips ? "Done" : "Edit") { [weak self] in self?.editingClips.toggle(); self?.render() }
        edit.titleLabel?.font = .systemFont(ofSize: 14); edit.widthAnchor.constraint(equalToConstant: 55).isActive = true; header.addArrangedSubview(edit)
        if !clipboardAccess {
            note("Enable Allow Full Access: Settings → General → Keyboard → Keyboards → S23 Style. This lets the keyboard save copied items.")
        } else {
            let controls = row(height: 36); controls.distribution = .fill
            let retry = button("Save copied item") { [weak self] in self?.captureClipboard(force: true) }
            retry.titleLabel?.font = .systemFont(ofSize: 14); controls.addArrangedSubview(retry)
            let receiver = ClipboardPasteReceiver(frame: .zero)
            receiver.receive = { [weak self] providers in self?.history.accept(providers) { [weak self] in self?.render() } }
            let config = UIPasteControl.Configuration(); config.displayMode = .iconAndLabel
            let paste = UIPasteControl(configuration: config); paste.target = receiver; paste.translatesAutoresizingMaskIntoConstraints = false
            receiver.addSubview(paste)
            NSLayoutConstraint.activate([
                paste.leadingAnchor.constraint(equalTo: receiver.leadingAnchor), paste.trailingAnchor.constraint(equalTo: receiver.trailingAnchor),
                paste.centerYAnchor.constraint(equalTo: receiver.centerYAnchor), receiver.widthAnchor.constraint(equalToConstant: 100)
            ])
            controls.addArrangedSubview(receiver)
            note(history.automatic ? "Auto-save on. Text and images save when this keyboard opens or is visible." : "Auto-save paused. Use Save copied item or Paste.")
        }
        if !history.message.isEmpty { note(history.message) }
        if !clipboardMessage.isEmpty { note(clipboardMessage) }
        if history.clips.isEmpty { note("No saved items yet. Copy some text, then reopen this keyboard.") }
        for start in stride(from: 0, to: history.clips.count, by: 3) {
            let grid = row(height: 76)
            for clip in history.clips[start..<min(start + 3, history.clips.count)] {
                let key = button(clip.text ?? "Copied image") { [weak self] in self?.useClip(clip) }
                key.titleLabel?.font = .systemFont(ofSize: 13); key.titleLabel?.numberOfLines = 3; key.titleLabel?.lineBreakMode = .byTruncatingTail
                key.contentEdgeInsets = UIEdgeInsets(top: 6, left: 7, bottom: 6, right: 7)
                key.accessibilityLabel = editingClips ? "Delete saved item: \(clip.text ?? "image")" : clip.text ?? "Copy saved image"
                if editingClips { key.setImage(KeyboardIcon.trash.image, for: .normal); key.tintColor = .systemRed }
                else if clip.kind == .image, let data = try? history.store?.imageData(for: clip),
                        let png = try? ClipboardHistory.thumbnail(data, maximum: 160), let image = UIImage(data: png) {
                    key.setTitle(nil, for: .normal); key.setImage(image, for: .normal); key.imageView?.contentMode = .scaleAspectFit
                }
                grid.addArrangedSubview(key)
            }
            while grid.arrangedSubviews.count < 3 { grid.addArrangedSubview(UIView()) }
        }
        if editingClips && !history.clips.isEmpty {
            row(height: 40).addArrangedSubview(button("Clear saved items") { [weak self] in self?.history.clear(); self?.render() })
        }
    }
    private func useClip(_ clip: Clip) {
        if editingClips { history.remove(clip); render(); return }
        if let text = clip.text { insert(text) }
        else if clipboardAccess, let data = try? history.store?.imageData(for: clip) {
            if let testTextView, let image = UIImage(data: data) {
                let attachment = NSTextAttachment(); attachment.image = image
                attachment.bounds = CGRect(x: 0, y: 0, width: 90, height: 90 * image.size.height / max(1, image.size.width))
                let range = testTextView.selectedRange
                testTextView.textStorage.replaceCharacters(in: range, with: NSAttributedString(attachment: attachment))
                testTextView.selectedRange = NSRange(location: range.location + 1, length: 0)
            } else {
                _ = history.prepareImage(clip)
                clipboardMessage = "Image ready. Hold the destination field and choose Paste. iOS keyboards cannot insert an image directly."
            }
            render()
        }
    }
    private func emojiPanel() {
        beginScrollablePanel()
        for line in ["😀😃😂🥹😊😍", "😎🤔😭😤🙏👍", "❤️🔥🎉✅👀💯"] {
            let stack = row(height: keyHeight)
            for character in line {
                let value = String(character)
                stack.addArrangedSubview(button(value) { [weak self] in self?.insert(value) })
            }
        }
        back()
    }
    private func cursorPanel() {
        beginScrollablePanel()
        note("Move the insertion point in the active text field.")
        let stack = row(height: 54)
        stack.addArrangedSubview(button("←") { [weak self] in self?.moveCursor(-1) })
        stack.addArrangedSubview(button("→") { [weak self] in self?.moveCursor(1) })
        back()
    }
    private func morePanel() {
        beginScrollablePanel()
        note("Hold letters for symbols and accents. Hold Delete to erase repeatedly. Hold and slide Space to move the cursor.")
        note("Clipboard holds 50 text or image items on this device. Capture runs when this keyboard is visible. S23 and ClipKey keep separate histories.")
        note("Translation, AI sentence rewriting, predictive text, swipe typing, and dictation are not available in this version.")
        back()
    }
}
