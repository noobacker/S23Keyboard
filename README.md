# S23 Style Keyboard 0.4

A native iPhone keyboard using the supplied Samsung layout references and Samsung/One UI control assets from [OneUIProject](https://github.com/OneUIProject/oneui-icons). See the bundled MIT attribution in ThirdParty/OneUIProject. [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) is a behavior reference, not a dependency.

## Features

- Permanent number row, two screenshot-matched symbol pages, English(India) space label, no custom globe/hide footer, and Clipboard/Settings toolbar.
- Offline English swipe typing with candidate choices and a limited built-in dictionary. This is an initial gesture decoder, not Samsung's prediction engine.
- More forgiving key touch regions, character callouts, hold symbols/accents, repeat deletion, and a dimmed two-direction cursor-control overlay on Space hold.
- Light, Dark and Auto appearance; inset scrollable settings; adjustable key height, haptics and original synthesized click volume. No Samsung audio recording is included.
- Private persistent text/image clipboard, capped at 50 combined items. At capacity, capture pauses instead of deleting old data. Saved text inserts directly. A saved image is prepared once for the destination app's native Paste action, without re-capturing its own clipboard write.
- Optional PhotoKit screenshot capture with a persistent checkpoint. After Photos authorization, new accessible screenshots are imported when the keyboard is running or next reopened. Private copies are never added to Photos.

## iOS limitations and permissions

Enable S23 Style in Settings → General → Keyboard → Keyboards and enable Full Access for haptic/clipboard functionality. Where available, choose Settings → Apps → S23 Style Keyboard → Paste from Other Apps → Allow once to suppress recurring paste prompts. An app cannot grant this setting itself. A native Paste control is included for explicit imports.

There is no public superuser permission that keeps a suspended keyboard capturing the clipboard or screenshots. Screenshot import requires Photos authorization and cannot guarantee immediate capture while closed. iOS's original screenshots still appear in Photos; this app does not delete them. A custom keyboard's text proxy cannot insert image attachments into another app. Hold that app's field and choose Paste after preparing an image.

Settings and history currently remain in the keyboard extension's private sandbox. The companion typing test uses the same controls but has a separate store. Existing ClipKey history is not read or changed. No network service, analytics, backend, typed-text log or API key is included. The build does not configure a shared App Group.

Vertical cursor movement in the companion text view uses actual text geometry. In other apps it uses exposed logical line context, so wrapped visual lines and limited host context may differ from Samsung. iOS may retain its own system globe/dismiss controls outside this keyboard's view.

## Build and install without local Xcode

Run the **Build keyboard IPA** workflow on this public repository. GitHub's Mac performs clipboard/swipe tests and builds the app/extension. Download the `S23Keyboard-unsigned` artifact and use Sideloadly to sign and install with the existing Apple ID, retaining the keyboard plug-in. Free signing requires periodic refresh; Sideloadly offers automatic refresh. No credentials or provisioning files are stored in this repository.

For local development, install Xcode and XcodeGen, run `xcodegen generate`, and open S23Keyboard.xcodeproj. Project signing is automatic. The test scheme includes an iPhone simulator interaction test.

See [UPDATE-0.4.md](UPDATE-0.4.md) for request-by-request scope and platform references. Do not interpret automated tests as verification of physical haptic feel, audible output, or every host application's behavior.
