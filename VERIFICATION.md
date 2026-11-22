# Revision 0.3.1 verification

[Final CI run](https://github.com/noobacker/S23Keyboard/actions/runs/44982863919) passed both jobs: the device build (including 15 clipboard tests) and the iPhone simulator interaction test. The app and keyboard extension compile and package successfully with matching versions and separate Info.plist files. The signed app was installed through Sideloadly; the connected iPhone reports version 0.3.1 under the existing bundle ID. Xcode was not installed locally.

The 15 clipboard tests cover permission retry, paused capture, own-write suppression, persistence, mixed image/text eviction, bounded storage, deletion, corrupt manifests and failed atomic writes. The simulator test verifies typing, a held symbol without duplicate base input, automatic capture of copied text, saved-item insertion, settings access, return to typing, symbols and emoji access.

On the connected physical iPhone, the app's typing-test screen was exercised through iPhone Mirroring:

- The test screen opens without the constraint-activation crash found and corrected during development.
- Tap Q enters q; holding W enters × without an additional w.
- Copying the test text automatically adds it to the Clipboard grid; tapping that saved clip inserts the complete text again.
- A sustained backspace press removes multiple characters.
- Shift inserts an uppercase letter; symbol insertion and the emoji panel work.
- Haptics, key sound, character preview, highlight and auto-save switches are on in the test screen.
- Full Access was enabled for the installed S23 keyboard with the user's explicit approval.
- Samsung/One UI control assets display in the toolbar and on utility keys. All 15 SVG assets and their bundled attribution were checked.

Still unverified: the physical feel/strength of vibration, audible feedback, the system-wide extension's typing across other apps, hold-and-slide cursor behavior, light appearance, landscape, VoiceOver and image paste into a host app. These are not implied by the companion-app and simulator checks. The containing app's test clipboard and the keyboard extension have separate histories; S23 also cannot directly read ClipKey's private saved items. Clipboard capture stops when the keyboard closes and remains subject to iOS paste permission.

Local command-line Swift compiled ClipboardCore but cannot import the Testing module on this Mac. The complete automated tests run on GitHub's Mac.
