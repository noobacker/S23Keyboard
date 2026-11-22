# Keyboard 0.4 request tracking

- Custom globe/hide footer removed. iOS can still show its own system keyboard controls.
- Toolbar now contains Clipboard and Settings. Emoji, Cursor and More are removed from that toolbar.
- Offline English gesture typing and three candidate choices added. The initial dictionary is intentionally limited; this is not Samsung's language model.
- Letter/number/punctuation touch regions cover gaps and rounded corners more generously.
- Screenshot-inspired black/charcoal styling, number row, both symbol pages and English(India) space label. Light, Dark and Auto appearance settings added.
- Settings use 20-point side insets, with adjustable key height, haptic strength and synthesized click volume. The click is original audio, not a Samsung recording.
- Holding Space displays a dimmed Cursor control overlay and accepts horizontal/vertical movement. In the companion app, vertical movement uses text geometry; in another host, only exposed logical line context is available, so wrapped-line movement cannot perfectly match Samsung.
- Image selection marks its pasteboard write so it is not re-saved as a new clip. The companion test supports direct image attachments. For another app, use its Paste command: Apple's keyboard proxy has no image attachment insertion method.
- At 50 combined text/image items, new capture pauses. Existing items and image files are never automatically evicted. Explicit user deletion remains available. Storage is private to the app/extension sandbox and is not written to Photos.
- Optional screenshot import requests Photos access, imports only accessible new screenshots, remembers a checkpoint, and catches up when S23 is next visible. Copies stay private. iOS's original screenshots still remain in Photos; the keyboard does not delete them.

## Platform limits

There is no public superuser grant for suspended keyboards or automatic clipboard access while closed. Full Access does not suppress paste authorization. Where available, choose Settings → Apps → S23 Style Keyboard → Paste from Other Apps → Allow once. The app cannot grant that setting itself. Native Paste buttons are also available for an explicit import.

Photos authorization must be granted through iOS before screenshot import can work. Capturing while both the app and extension are suspended cannot be guaranteed. Existing ClipKey history remains in ClipKey; this revision does not read another app's private storage or add a shared App Group.

Sources: [Apple keyboard text APIs](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards), [extension lifecycle](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html), [Apple paste privacy](https://developer.apple.com/videos/play/wwdc2022/10096/), [Photos authorization](https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)).
