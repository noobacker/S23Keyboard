import SwiftUI
import UIKit

struct KeyboardLab: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> KeyboardLabController { KeyboardLabController() }
    func updateUIViewController(_ controller: KeyboardLabController, context: Context) {}
}

final class KeyboardLabController: UIViewController {
    private let text = UITextView()
    private let keyboard = KeyboardViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
        let hint = UILabel(); hint.text = "Try taps, holds, space-bar cursor movement and the Clipboard panel. These are the same controls as the installed keyboard."
        hint.font = .systemFont(ofSize: 14); hint.textColor = .secondaryLabel; hint.numberOfLines = 0; stack.addArrangedSubview(hint)
        text.font = .systemFont(ofSize: 20); text.backgroundColor = .secondarySystemBackground
        text.layer.cornerRadius = 8; text.accessibilityLabel = "Keyboard test text"
        text.heightAnchor.constraint(equalToConstant: 100).isActive = true
        text.inputView = UIView(frame: .zero); text.autocorrectionType = .no; text.spellCheckingType = .no
        stack.addArrangedSubview(text)
        let controls = UIStackView(); controls.axis = .horizontal; controls.distribution = .fillEqually; controls.spacing = 8
        for title in ["Copy test text", "Clear test text"] {
            let button = UIButton(configuration: .bordered()); button.setTitle(title, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                if title == "Copy test text" { UIPasteboard.general.string = self.text.text }
                else { self.text.text = "" }
            }, for: .touchUpInside)
            controls.addArrangedSubview(button)
        }
        controls.heightAnchor.constraint(equalToConstant: 40).isActive = true; stack.addArrangedSubview(controls)
        keyboard.testTextView = text
        addChild(keyboard); stack.addArrangedSubview(keyboard.view); keyboard.didMove(toParent: self)
        let note = UILabel(); note.text = "The app test and keyboard extension have separate saved-item stores. Full Access must be enabled separately for the system keyboard."
        note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabel; note.numberOfLines = 0; stack.addArrangedSubview(note)
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); text.becomeFirstResponder() }
}
