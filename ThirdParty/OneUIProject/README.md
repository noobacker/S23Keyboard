# OneUIProject icons

Source: https://github.com/OneUIProject/oneui-icons
Pinned revision: `3808bd6965251e7616b1a0a286c75f5d533715e7`
License: MIT, included in LICENSE and bundled with the app/extension.

The upstream project describes these as icons found in Samsung apps. Keyboard
shift, delete and enter use its keyboard-specific assets. Toolbar controls use
its named One UI assets. These are community-distributed Samsung/One UI assets,
not a claim that Samsung supplied or endorsed this app. They are not guaranteed
to match every Samsung Keyboard version.

Android path geometry is preserved in the SVGs in Keyboard/Assets.xcassets.
Only color references are resolved to black for template tinting, and Android
fill/stroke attribute names are converted to SVG. Reproduce with
`python3 Scripts/import-oneui-icons.py`.
