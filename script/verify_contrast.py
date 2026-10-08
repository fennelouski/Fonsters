#!/usr/bin/env python3
"""Measure the actual opaque native color assets in both system appearances."""
import json
from pathlib import Path
import sys

catalog = Path(__file__).resolve().parent.parent / 'Fonsters/FonsterChrome.xcassets'


def color(name, scheme):
    entries = json.loads((catalog / (name + '.colorset/Contents.json')).read_text())['colors']
    entry = next(c for c in entries if bool(c.get('appearances')) == (scheme == 'dark'))
    assert entry['color']['color-space'] == 'srgb'
    values = entry['color']['components']
    assert float(values['alpha']) == 1, 'Only opaque surfaces are covered'
    return [float(values[c]) for c in ('red', 'green', 'blue')]


def luminance(rgb):
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))


pairs = [(fg, bg) for fg in ('ChromePrimary', 'ChromeSecondary')
         for bg in ('ChromeBackground', 'ChromeSurface', 'CompanyWash')]
for tone in ('Company', 'Play', 'World', 'Quiet'):
    pairs += [(tone + 'Ink', tone + 'Wash'), ('ChromeOnSelection', tone + 'Ink')]
for brand in ('Accent', 'Blue', 'Violet', 'Teal', 'Amber'):
    pairs += [('Brand' + brand, bg) for bg in ('ChromeBackground', 'ChromeSurface')]
results = []
for scheme in ('light', 'dark'):
    for fg, bg in pairs:
        a, b = sorted([luminance(color(fg, scheme)), luminance(color(bg, scheme))])
        ratio = (b + 0.05) / (a + 0.05)
        results.append({'scheme': scheme, 'foreground': fg, 'background': bg,
                        'ratio': round(ratio, 3), 'pass': ratio >= 4.5})
report = {'formula': 'WCAG sRGB relative luminance; opaque text/control surfaces',
          'minimumBodyText': 4.5, 'results': results}
print(json.dumps(report, indent=2))
print(f"{len(results)} pairs; minimum {min(r['ratio'] for r in results)}:1", file=sys.stderr)
raise SystemExit(0 if all(r['pass'] for r in results) else 1)
