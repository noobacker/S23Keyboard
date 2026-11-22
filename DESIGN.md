# S23 keyboard revision 0.3

Keep the approved direction: Samsung key placement, permanent number row and symbol hints with iOS keycaps, system typography and automatic light/dark appearance. ENERGY 1 / RHYTHM 1 / MOTION 0. Touch highlights and callouts show the current input state; they do not animate or bounce. Shadows distinguish physical key surfaces, not panels.

The toolbar uses original, consistent 24-point vector drawings for emoji, clipboard, cursor, settings and more. These are recreations of familiar keyboard controls, not extracted Samsung assets. Clipboard has a visible label and selected background so users can find it. Utility keys use vector drawings rather than Unicode substitutions. Native iOS emoji remain content in the emoji picker.

Input callouts stay inside the keyboard extension's bounds. Holds show the symbol/accents and slide selection; releasing commits one alternate and suppresses the ordinary key tap. Space holds move the cursor. The clipboard uses a three-column text/image grid, scrolling vertically; its permissions, empty state and read failures remain visible. Settings scroll to fit the same fixed keyboard height. VoiceOver actions provide access to alternate characters without hold gestures.

KeyboardKit is a behavior/UI reference for callouts, feedback and clipboard controls. No KeyboardKit binary, source, subscription or Pro feature is integrated. The capture state and file store are reused from the user's local ClipKey project. S23's extension retains its own sandbox history, preserving the existing free-signing route.
