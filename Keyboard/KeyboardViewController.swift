import UIKit

final class ClickInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

// Native UIKit styling; iOS renders emoji with its own emoji font.
private enum KeyboardStyle {
    static let background = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.12, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1) }
    static let key = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.34, alpha: 1) : .white }
    static let utility = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.24, alpha: 1) : UIColor(red: 0.68, green: 0.70, blue: 0.73, alpha: 1) }
    static let pressed = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.49, alpha: 1) : UIColor(red: 0.70, green: 0.75, blue: 0.83, alpha: 1) }
}

final class KeyButton: UIButton {
    var highlightEnabled = true
    var restingColor = KeyboardStyle.key { didSet { updateAppearance() } }
    override var isHighlighted: Bool { didSet { updateAppearance() } }
    private func updateAppearance() {
        backgroundColor = isHighlighted && highlightEnabled ? KeyboardStyle.pressed : restingColor
    }
}

final class KeyboardViewController: UIInputViewController {
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
    private var clips: [String] {
        get { defaults.stringArray(forKey: "clips") ?? [] }
        set { defaults.set(newValue, forKey: "clips") }
    }
    private var highlights: Bool {
        defaults.object(forKey: "highlights") == nil || defaults.bool(forKey: "highlights")
    }
    private var keyHeight: CGFloat {
        let value = defaults.double(forKey: "keyHeight")
        return value == 0 ? 43 : CGFloat(value)
    }

    override func loadView() {
        view = ClickInputView(frame: .zero, inputViewStyle: .keyboard)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyboardStyle.background
        root.axis = .vertical
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -4)
        ])
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 360)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true
        render()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDeleting()
    }
    private func feedback() {
        if defaults.bool(forKey: "sound") { UIDevice.current.playInputClick() }
        if defaults.bool(forKey: "haptics") {
            let strength = defaults.double(forKey: "strength")
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: strength == 0 ? 0.5 : strength)
        }
    }
    private func clearRoot() {
        stopDeleting()
        root.arrangedSubviews.forEach { root.removeArrangedSubview($0); $0.removeFromSuperview() }
    }
    private func row(height: CGFloat) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.distribution = .fillEqually
        stack.heightAnchor.constraint(equalToConstant: height).isActive = true
        root.addArrangedSubview(stack)
        return stack
    }
    private func button(_ title: String, hint: String? = nil, action: @escaping () -> Void) -> KeyButton {
        let key = KeyButton(type: .custom)
        key.highlightEnabled = highlights
        key.restingColor = ["⇧", "⇪", "⌫", "!#1", "ABC", "↵", "Search", "Send", "Go", "Done"].contains(title)
            ? KeyboardStyle.utility : KeyboardStyle.key
        key.layer.cornerRadius = 6
        key.layer.shadowColor = UIColor.black.cgColor
        key.layer.shadowOpacity = 0.22
        key.layer.shadowOffset = CGSize(width: 0, height: 1)
        key.layer.shadowRadius = 0.5
        key.setTitle(title, for: .normal)
        key.setTitleColor(.label, for: .normal)
        key.titleLabel?.font = .systemFont(ofSize: title.count > 3 ? 14 : 25, weight: .regular)
        key.accessibilityLabel = title
        key.addAction(UIAction { [weak self] _ in self?.feedback(); action() }, for: .touchUpInside)
        if let hint = hint {
            let label = UILabel()
            label.text = hint
            label.textColor = .secondaryLabel
            label.font = .systemFont(ofSize: 9)
            label.translatesAutoresizingMaskIntoConstraints = false
            key.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: key.topAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: key.trailingAnchor, constant: -3)
            ])
            let press = UILongPressGestureRecognizer(target: self, action: #selector(longSymbol(_:)))
            press.minimumPressDuration = 0.4
            key.addGestureRecognizer(press)
            key.accessibilityHint = "Hold for \(hint)"
            key.accessibilityValue = hint
        }
        return key
    }
    @objc private func longSymbol(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let key = gesture.view as? KeyButton,
              let symbol = key.accessibilityValue else { return }
        feedback()
        textDocumentProxy.insertText(symbol)
    }
    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        if shift && !capsLock { shift = false; render() }
    }
    private func toolbar() {
        let bar = row(height: 36)
        for (title, destination) in [("☺", "emoji"), ("↔", "cursor"), ("⚙", "settings"), ("▤", "clipboard"), ("…", "more")] {
            let key = button(title) { [weak self] in self?.panel = destination; self?.render() }
            key.restingColor = .clear
            key.layer.shadowOpacity = 0
            bar.addArrangedSubview(key)
        }
    }
    private func render() {
        clearRoot()
        heightConstraint?.constant = 6 * keyHeight + 84
        toolbar()
        switch panel {
        case "settings": settingsPanel()
        case "clipboard": clipboardPanel()
        case "emoji": emojiPanel()
        case "cursor": cursorPanel()
        case "more": morePanel()
        default: keys()
        }
        let footer = row(height: 28)
        let globe = KeyButton(type: .custom)
        globe.setTitle("🌐", for: .normal)
        globe.titleLabel?.font = .systemFont(ofSize: 22)
        globe.restingColor = .clear
        globe.accessibilityLabel = "Next keyboard"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        // UIKit handles globe taps and the hold-to-choose keyboard menu.
        footer.addArrangedSubview(globe)
        footer.addArrangedSubview(button("⌄") { [weak self] in self?.dismissKeyboard() })
    }
    private func keys() {
        let numbers = row(height: keyHeight - 8)
        for character in "1234567890" {
            let value = String(character)
            numbers.addArrangedSubview(button(value) { [weak self] in self?.insert(value) })
        }
        let letters = symbols
            ? (secondSymbols ? ["~`|•√π÷×¶∆", "£¢€¥^°={}\\", "%©®™✓[]"] : ["@#$%&*-+()", "_\"':;!?/=", "<>€£¥•\\"])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        let hints = [Array("+×÷=_<>[]"), Array("!@#£%&*()"), Array("-\"':;!?/")]
        for (index, line) in letters.enumerated() {
            let stack = row(height: keyHeight)
            if index == 1 {
                let spacer = UIView(); stack.addArrangedSubview(spacer)
                spacer.widthAnchor.constraint(equalToConstant: 9).isActive = true
                stack.distribution = .fillProportionally
            }
            if index == 2 {
                let key = button(symbols ? (secondSymbols ? "1/2" : "2/2") : (capsLock ? "⇪" : "⇧")) { [weak self] in
                    guard let self = self else { return }
                    if self.symbols { self.secondSymbols.toggle() }
                    else if self.shift { self.capsLock.toggle(); self.shift = self.capsLock }
                    else { self.shift = true }
                    self.render()
                }
                key.accessibilityLabel = symbols ? "More symbols" : "Shift; tap again for caps lock"
                stack.addArrangedSubview(key)
            }
            for (column, character) in line.enumerated() {
                let value = String(character)
                let output = !symbols && shift ? value.uppercased() : value
                let hint = !symbols && column < hints[index].count ? String(hints[index][column]) : nil
                stack.addArrangedSubview(button(output, hint: hint) { [weak self] in self?.insert(output) })
            }
            if index == 1 {
                let spacer = UIView(); stack.addArrangedSubview(spacer)
                spacer.widthAnchor.constraint(equalToConstant: 9).isActive = true
            }
            if index == 2 {
                let delete = button("⌫") { [weak self] in self?.textDocumentProxy.deleteBackward() }
                delete.accessibilityLabel = "Delete"
                delete.addTarget(self, action: #selector(startDeleting), for: .touchDown)
                delete.addTarget(self, action: #selector(stopDeleting), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
                stack.addArrangedSubview(delete)
            }
        }
        let bottom = row(height: keyHeight)
        bottom.distribution = .fill
        bottom.addArrangedSubview(button(symbols ? "ABC" : "!#1") { [weak self] in self?.symbols.toggle(); self?.render() })
        bottom.addArrangedSubview(button(",") { [weak self] in self?.insert(",") })
        let space = button("English (UK)") { [weak self] in self?.insert(" ") }
        space.accessibilityLabel = "Space"
        bottom.addArrangedSubview(space)
        bottom.addArrangedSubview(button(".") { [weak self] in self?.insert(".") })
        let returnLabel: String
        switch textDocumentProxy.returnKeyType ?? .default {
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
    }
    @objc private func startDeleting() {
        delayTimer?.invalidate()
        delayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }
    @objc private func stopDeleting() {
        delayTimer?.invalidate(); deleteTimer?.invalidate()
        delayTimer = nil; deleteTimer = nil
    }
    private func note(_ text: String) {
        let label = UILabel(); label.text = text; label.numberOfLines = 0
        label.textColor = .secondaryLabel; label.font = .systemFont(ofSize: 13)
        root.addArrangedSubview(label)
    }
    private func back() {
        row(height: 36).addArrangedSubview(button("Back to keyboard") { [weak self] in self?.panel = "keys"; self?.render() })
    }
    private func toggle(_ title: String, key: String, value: Bool) {
        let stack = row(height: 34)
        let label = UILabel(); label.text = title; label.textColor = .label
        let control = UISwitch(); control.isOn = value
        control.addAction(UIAction { [weak self, weak control] _ in
            self?.defaults.set(control?.isOn ?? false, forKey: key)
        }, for: .valueChanged)
        stack.distribution = .fill; stack.addArrangedSubview(label); stack.addArrangedSubview(control)
    }
    private func slider(_ title: String, key: String, value: Float, range: ClosedRange<Float>) {
        note(title)
        let control = UISlider(); control.minimumValue = range.lowerBound; control.maximumValue = range.upperBound; control.value = value
        control.addAction(UIAction { [weak self, weak control] _ in self?.defaults.set(control?.value ?? value, forKey: key) }, for: .valueChanged)
        root.addArrangedSubview(control)
    }
    private func settingsPanel() {
        toggle("Tap highlight", key: "highlights", value: highlights)
        toggle("Key sound", key: "sound", value: defaults.bool(forKey: "sound"))
        toggle("Haptics", key: "haptics", value: defaults.bool(forKey: "haptics"))
        slider("Haptic strength", key: "strength", value: defaults.object(forKey: "strength") == nil ? 0.5 : defaults.float(forKey: "strength"), range: 0.1...1)
        slider("Key height", key: "keyHeight", value: Float(keyHeight), range: 38...52)
        back()
    }
    private func clipboardPanel() {
        note("Saved clips stay on this device. Tap a clip to insert it. Import only when you want to save copied text.")
        row(height: 36).addArrangedSubview(button("Import copied text") { [weak self] in
            guard let self = self else { return }
            guard self.hasFullAccess else {
                self.note("Enable Allow Full Access for this keyboard in iPhone Settings to import copied text.")
                return
            }
            if let text = UIPasteboard.general.string, !text.isEmpty {
                self.clips = Array(([text] + self.clips.filter { $0 != text }).prefix(20))
                self.render()
            }
        })
        let scroll = UIScrollView()
        scroll.heightAnchor.constraint(equalToConstant: 145).isActive = true
        root.addArrangedSubview(scroll)
        let list = UIStackView(); list.axis = .vertical; list.spacing = 5
        list.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            list.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        for clip in clips {
            let key = button(String(clip.prefix(70))) { [weak self] in self?.textDocumentProxy.insertText(clip) }
            key.heightAnchor.constraint(equalToConstant: 36).isActive = true; list.addArrangedSubview(key)
        }
        row(height: 34).addArrangedSubview(button("Clear saved clips") { [weak self] in self?.clips = []; self?.render() })
        back()
    }
    private func emojiPanel() {
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
        note("Move the insertion point in the active text field.")
        let stack = row(height: 54)
        stack.addArrangedSubview(button("←") { [weak self] in self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1) })
        stack.addArrangedSubview(button("→") { [weak self] in self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1) })
        back()
    }
    private func morePanel() {
        note("This first build includes typing, number and symbol rows, long-press symbols, emoji, cursor controls, saved clips, and feedback settings.")
        note("Translation, AI sentence rewriting, predictive text, swipe typing, and dictation are not available in this version.")
        back()
    }
}
