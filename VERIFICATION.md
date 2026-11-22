# Revision 0.3 verification

The first cloud build of this revision passed 15 clipboard tests and compiled both the containing app and keyboard extension. Tests cover capture permission retry, paused capture, own-write suppression, persistence, mixed image/text eviction, bounded storage, deletion, corrupted manifests and failed atomic writes. Local command-line Swift cannot import the Testing module on this Mac, so the tests run on the cloud Mac instead.

Runtime checks to complete on the signed update: taps, previews, long holds without duplicate insertion, repeat-delete cancellation, space cursor movement, all panels, dark/light appearance, portrait/landscape, clipboard reopening and permission refusal. Mirroring can exercise the app typing-test screen. Physical touch is required to judge haptic strength and sound. Full Access and paste authorization apply separately to the installed extension.

Layout/interaction changes: equal-width character keys, proportional home-row indent and utility widths; scrollable panels keep settings/clipboard content within the keyboard height; original vector controls have action names and a labeled toolbar; alternate characters also have VoiceOver custom actions. No claim of complete Samsung parity or exact Samsung assets is made.
