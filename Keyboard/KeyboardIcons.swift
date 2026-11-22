import UIKit

/// OneUIProject assets preserve the upstream Samsung/One UI path geometry.
/// Sources, pinned revision and license are in ThirdParty/OneUIProject.
enum KeyboardIcon: String {
    case emoji, clipboard, cursor, settings, more, globe, shift, capsLock
    case delete, enter, dismiss, keyboard, trash, left, right

    var image: UIImage {
        guard let image = UIImage(named: "Samsung_\(rawValue)") else {
            assertionFailure("Missing keyboard icon: \(rawValue)")
            return UIImage()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
