"""Convert pinned OneUIProject Android vector assets into iOS SVG image sets."""
import json
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET

REVISION = '3808bd6965251e7616b1a0a286c75f5d533715e7'
BASE = f'https://raw.githubusercontent.com/OneUIProject/oneui-icons/{REVISION}'
ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'
ICONS = {
    'emoji': 'emoji', 'clipboard': 'clipboard', 'cursor': 'move',
    'settings': 'settings_outline', 'more': 'more', 'globe': 'internet_website',
    'shift': 'keyboard_btn_shift_outline', 'capsLock': 'keyboard_btn_shift',
    'delete': 'keyboard_btn_delete', 'enter': 'keyboard_btn_enter',
    'dismiss': 'keyboard_arrow_down', 'keyboard': 'keyboard', 'trash': 'delete_outline',
    'left': 'keyboard_arrow_left', 'right': 'keyboard_arrow_right',
}

def color(value):
    if value in (None, '#00000000'): return 'none'
    if value.startswith('@'): return '#000000'
    if value.startswith('#') and len(value) == 9:
        if value[1:3] != 'FF' and value[1:3] != 'ff':
            raise ValueError(f'Unsupported alpha color: {value}')
        return '#' + value[3:]
    return value

def convert(element):
    if element.tag != 'path': raise ValueError(f'Unexpected vector node: {element.tag}')
    get = lambda name, default=None: element.get(ANDROID + name, default)
    attributes = {'d': get('pathData'), 'fill': color(get('fillColor'))}
    if get('fillType'): attributes['fill-rule'] = 'evenodd' if get('fillType') == 'evenOdd' else 'nonzero'
    if get('strokeColor'):
        attributes.update({'stroke': color(get('strokeColor')), 'stroke-width': get('strokeWidth', '1'),
                           'stroke-linecap': get('strokeLineCap', 'butt'), 'stroke-linejoin': get('strokeLineJoin', 'miter')})
    for name in ('fillAlpha', 'strokeAlpha'):
        if get(name): attributes['fill-opacity' if name == 'fillAlpha' else 'stroke-opacity'] = get(name)
    return ET.Element('path', attributes)

sources = ROOT / 'ThirdParty/OneUIProject'
sources.mkdir(parents=True, exist_ok=True)
assets = ROOT / 'Keyboard/Assets.xcassets'
assets.mkdir(parents=True, exist_ok=True)
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
for name, source in ICONS.items():
    filename = f'ic_oui_{source}.xml'
    data = urllib.request.urlopen(f'{BASE}/lib/src/main/res/drawable/{filename}').read()
    (sources / filename).write_bytes(data)
    vector = ET.fromstring(data)
    width, height = vector.get(ANDROID + 'viewportWidth'), vector.get(ANDROID + 'viewportHeight')
    svg = ET.Element('svg', {'xmlns': 'http://www.w3.org/2000/svg', 'width': '24', 'height': '24', 'viewBox': f'0 0 {width} {height}'})
    for child in vector: svg.append(convert(child))
    target = assets / f'Samsung_{name}.imageset'
    target.mkdir(parents=True, exist_ok=True)
    (target / f'{name}.svg').write_bytes(ET.tostring(svg, encoding='utf-8', xml_declaration=True))
    (target / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': f'{name}.svg', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'}
    }, indent=2) + '\n')
license_data = urllib.request.urlopen(f'{BASE}/LICENSE').read()
(sources / 'LICENSE').write_bytes(license_data)
resource = ROOT / 'Keyboard/Resources'
resource.mkdir(parents=True, exist_ok=True)
(resource / 'OneUIProject-LICENSE.txt').write_bytes(license_data)
(sources / 'README.md').write_text(f'''# OneUIProject icons

Source: https://github.com/OneUIProject/oneui-icons
Pinned revision: `{REVISION}`
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
''')
print(f'Imported {len(ICONS)} One UI vectors from {REVISION}')
