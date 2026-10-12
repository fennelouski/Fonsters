#!/usr/bin/env python3
"""Validate the authored worker handoff offline; never generates/imports audio."""
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'docs/prototype/audio-worker'
catalogue = json.loads((folder / 'catalogue.json').read_text())
assert catalogue['schema_version'] == 1
assert catalogue['status'] == 'prepared_not_generated'
assert catalogue['generation_authorized'] is False and catalogue['api_calls'] == 0
cues = catalogue['cues']
assets = catalogue['assets']
assert len({c['id'] for c in cues}) == len(cues)
assert len({a['asset_id'] for a in assets}) == len(assets)
assert len({a['filename'] for a in assets}) == len(assets)
by_id = {c['id']: c for c in cues}
voices = {v['id']: v for v in catalogue['voices']}
assert {v['legacy_index'] for v in voices.values()} == {0, 1, 2}
for cue in cues:
    matching = [a for a in assets if a['cue_id'] == cue['id']]
    assert len(matching) == cue['takes_per_voice'] * (len(voices) if cue['voiced'] else 1)
    assert cue['runtime_status'] in {'current_bank', 'requires_wiring'}
    assert cue['delivery_status'] == 'not_generated'
    assert 0 < cue['duration_seconds']['min'] <= cue['duration_seconds']['max'] <= 18
for asset in assets:
    cue = by_id[asset['cue_id']]
    assert asset['priority'] == cue['priority']
    assert asset['status'] == 'not_generated'
    assert re.fullmatch(r'[a-z0-9_]+\.wav', asset['filename'])
    assert asset['runtime_status'] == cue['runtime_status']
    assert asset['loop'] == cue['loop']
    assert asset['voice'] in voices if cue['voiced'] else asset['voice'] == 'none'
    assert 1 <= asset['take'] <= cue['takes_per_voice']
    assert asset['duration_min_seconds'] == cue['duration_seconds']['min']
    assert asset['duration_max_seconds'] == cue['duration_seconds']['max']
    assert len(asset['prompt']) >= 100
    if asset['bpm']:
        assert asset['loop'] and asset['loop_bars'] == 4 and asset['beats_per_bar'] == 4
        duration = asset['loop_duration_target_seconds']
        assert abs(duration - 960 / asset['bpm']) < 1e-6
        assert asset['duration_min_seconds'] <= duration <= asset['duration_max_seconds']
    if cue['legacy_event']:
        assert asset['filename'] == f"fonster_{cue['legacy_event']}_{voices[asset['voice']]['legacy_index']}.wav"
    else:
        assert asset['runtime_status'] == 'requires_wiring'

def rows(name):
    with (folder / name).open(newline='') as stream:
        return list(csv.DictReader(stream))

queue = rows('production-queue.csv')
assert len(queue) == len(assets)
for authored, exported in zip(assets, queue):
    for key in exported:
        expected = authored.get(key)
        assert exported[key] == ('' if expected is None else str(expected)), (authored['asset_id'], key)
first = rows('first-batch.csv')
assert len(first) == 15 and all(r['priority'] == 'P0' for r in first)
manifest = json.loads((root / 'docs/prototype/sound-manifest.json').read_text())
assert {a['filename'] for a in first} == {m['file'] for m in manifest}
for entry in manifest:
    # Existing recordings are preserved, not silently replaced by this catalogue.
    path = root / 'Fonsters/Playroom/Sounds' / entry['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
review = rows('review-sheet.csv')
assert {r['asset_id'] for r in review} == {a['asset_id'] for a in assets}
assert all(r['technical_status'] == r['audition_status'] == 'pending' and r['license_status'] == 'unverified' for r in review)
provenance = json.loads((folder / 'provenance-template.json').read_text())
assert provenance['records'][0]['asset_id'] in {a['asset_id'] for a in assets}
assert provenance['records'][0]['review']['approved_for_bundle'] is False
print(f"PASS: {len(cues)} cues / {len(assets)} assets; {dict(Counter(a['priority'] for a in assets))}")
print('PASS: unique IDs/files, queue and review correspondence, 15 exact starter filenames, dance timing, pending provenance, unchanged placeholder hashes; zero API calls')
