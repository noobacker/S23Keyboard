# S23 Style Keyboard 0.3

Native Swift keyboard extension with a setup app and an interactive typing test. Uses iOS keycaps with Samsung-style placement, a number row, hold symbols/accents, and a labeled tool strip. The UI and interaction reference is [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit); no KeyboardKit binary or paid feature is integrated. Toolbar and utility icons are original vector recreations, not extracted Samsung assets.

## Build and install on your iPhone

Requires a Mac with Xcode, an Apple ID, and XcodeGen.

1. Install Xcode from the Mac App Store and launch it once to finish setup.
2. Install XcodeGen (`brew install xcodegen` if Homebrew is installed).
3. In Terminal, enter this folder and run `xcodegen generate`.
4. Open `S23Keyboard.xcodeproj` in Xcode.
5. In Signing & Capabilities, choose your Apple development team for **both** the S23Keyboard app and Keyboard extension. Change both bundle identifiers to unique values if necessary, preserving the parent prefix.
6. Connect your iPhone, choose it as the run destination, and enable Developer Mode if Xcode requests it.
7. Run the S23Keyboard scheme. Follow any device trust instructions from Xcode.
8. On iPhone, open Settings → General → Keyboard → Keyboards → Add New Keyboard → S23 Style.
9. Open Notes or the included test field and hold the globe to switch keyboards.

Personal development signing is for testing and may require periodic re-signing. Long-term distribution needs an appropriate Apple signing/distribution route. No developer credentials or signing certificates are included.

## Implemented in source

- Apple-inspired rounded keycaps, subtle shadows, system typography, light/dark colors and a 43-point default key height.
- Samsung-style number row, symbol hints, toolbar, dedicated comma/full stop and English (UK) space bar.
- Emoji characters rendered by iOS using its native emoji appearance; the prototype emoji picker remains a limited custom panel.
- Letters, shift/caps lock, two symbol pages, punctuation and return labels.
- Character preview callouts, hold-and-slide symbol/accent selection, and hold-to-repeat deletion without an extra release deletion.
- Hold and slide Space to move the cursor.
- Basic emoji panel and cursor left/right controls.
- Keyboard-local settings: highlight, system click toggle, haptic toggle/strength and height.
- ClipKey-style automatic capture when the keyboard opens and while it is visible, plus explicit save and native Paste controls. Holds 50 text/image clips with insertion, image copying, individual deletion and clear. Existing S23 text clips migrate on first use.
- Retained, prepared haptic generator and touch-down feedback. Sound and haptics default on; existing explicit preferences are preserved. Settings include a feedback test.
- A typing-test screen in the containing app uses the same keyboard controls for testing through iPhone Mirroring.
- System keyboard switch menu and dismiss control.

The extension stores clips locally in its own protected, backup-excluded Application Support folder. No typed-text logging, backend, analytics, API key or network service is included. Auto-save defaults on and can be paused. Capture requires Allow Full Access, and iOS may additionally request paste permission. A denied read is not repeatedly attempted by the timer; reopen the keyboard or tap Save copied item to retry. The watcher stops when the keyboard closes. It cannot capture everything while closed or read ClipKey's private saved history. The app typing test and extension also have separate histories because this free-signing build has no shared App Group.

Enable **Settings → General → Keyboard → Keyboards → S23 Style → Allow Full Access** for clipboard and haptic functionality. Ordinary typing works without it. Sound and haptics remain subject to device/iOS settings and need physical-device confirmation.

## Not implemented

Translation, AI grammar/meaning correction, swipe decoding, predictive text/autocorrect, multilingual layouts, GIFs/stickers, complete Samsung emoji catalogue, full themes, floating/one-handed mode, capture while the keyboard is closed, and voice dictation.

The single angled photo is insufficient to establish exact pixel measurements, all panels, or the complete feature set. Additional straight screenshots of the original keyboard, settings, clipboard and expanded toolbar would improve visual matching. This project uses text/system glyphs rather than extracted Samsung assets.

## Verification status

The app and embedded keyboard extension compiled successfully for a physical iPhone in Release configuration on a GitHub-hosted macOS runner on November 21, 2026. [Build log](https://github.com/noobacker/S23Keyboard/actions/runs/44972447390). Compilation does not verify runtime behavior: simulator, physical-device typing, feedback and pixel comparison remain unverified.

## Build without installing Xcode locally

Run the **Build keyboard IPA** workflow in this repository's GitHub Actions tab. It uses Xcode on a hosted Mac, with a ten-minute job timeout, and uploads a seven-day `S23Keyboard-unsigned` artifact. Download and extract that artifact to obtain the IPA. The unsigned IPA cannot run until a signing tool signs both the app and its keyboard extension.

On this Mac, Sideloadly is installed. Select the connected, trusted iPhone, load the IPA, and retain the keyboard plug-in (the advanced options should show **Dropping 0 of 1 plug-ins**). Sign and install with your Apple ID, then enable S23 Style in iPhone keyboard settings. A free Apple account requires periodic re-signing; Sideloadly offers automatic refresh. Never commit Apple ID credentials, signing certificates or provisioning profiles to the repository.

Before daily use, build in Xcode and check: insertion and return in Notes/Messages; tap/hold globe; all symbols and emoji; caps lock; repeat deletion and cancellation; portrait/landscape and smaller screens; all feedback settings; persistence after switching apps; clipboard with Full Access off/on; large clips and clear; VoiceOver; and secure-field fallback.

## Apple platform references

- https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface
- https://developer.apple.com/documentation/uikit/uidevice/playinputclick()

Some host apps disallow custom keyboards, and secure text fields use the system keyboard. Custom keyboard access to surrounding text is limited by the host. A full Samsung-equivalent experience cannot be guaranteed across iOS.

## Appearance update

See [DESIGN.md](DESIGN.md) for visual decisions and [VERIFICATION.md](VERIFICATION.md) for the revision's checks. KeyboardKit informs the behavior of feedback, callouts and clipboard controls; it is not a dependency. Original Samsung icon files are still needed for an exact asset match.
