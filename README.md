# S23 Style Keyboard — iPhone prototype 0.2

Native Swift keyboard extension with a small setup app. Uses Apple-inspired key styling with the Samsung-style placement requested by Harshal. The Samsung photos guide placement and feature goals, not the key appearance. This is source code, not a signed installable IPA or a finished Samsung feature replica.

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
- Long-press symbol entry and hold-to-repeat deletion.
- Basic emoji panel and cursor left/right controls.
- Keyboard-local settings: highlight, system click toggle, haptic toggle/strength and height.
- Explicit clipboard import, up to 20 saved text clips, insert and clear.
- System keyboard switch menu and dismiss control.

Settings and saved clips use the extension's local preferences. No typed-text logging, backend, analytics, API key, or network request is included. Clipboard import is initiated only by tapping Import. Full Access is requested in the extension configuration for that feature; ordinary typing does not require it. Sound and haptic behavior must be verified on a physical device and remains subject to iOS/device settings.

## Not implemented

Translation, AI grammar/meaning correction, swipe decoding, predictive text/autocorrect, multilingual layouts, GIFs/stickers, complete Samsung emoji catalogue, full themes, floating/one-handed mode, automatic background clipboard capture, and voice dictation. The toolbar does not pretend those tools work. The main photo's microphone is omitted rather than shown as a nonfunctional recording button.

The single angled photo is insufficient to establish exact pixel measurements, all panels, or the complete feature set. Additional straight screenshots of the original keyboard, settings, clipboard and expanded toolbar would improve visual matching. This project uses text/system glyphs rather than extracted Samsung assets.

## Verification status

Configuration and source structure checked in the creation environment. Xcode and the iOS SDK are unavailable there: **no iOS compilation, simulator run, signing, physical-device test or pixel-comparison has been performed**. Treat this as an uncompiled first prototype.

Before daily use, build in Xcode and check: insertion and return in Notes/Messages; tap/hold globe; all symbols and emoji; caps lock; repeat deletion and cancellation; portrait/landscape and smaller screens; all feedback settings; persistence after switching apps; clipboard with Full Access off/on; large clips and clear; VoiceOver; and secure-field fallback.

## Apple platform references

- https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface
- https://developer.apple.com/documentation/uikit/uidevice/playinputclick()

Some host apps disallow custom keyboards, and secure text fields use the system keyboard. Custom keyboard access to surrounding text is limited by the host. A full Samsung-equivalent experience cannot be guaranteed across iOS.

## Appearance update

This revision changes presentation only. Button actions and feature availability are unchanged. It uses UIKit styling rather than CSS because it is a native iPhone keyboard extension. Apple key sizing is a visual target, not a pixel-verified match; the extra number row and punctuation keys affect total keyboard geometry. The new Samsung screenshots also record AI rewriting/tone and translation as future feature references; those capabilities are still not implemented.
