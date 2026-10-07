#!/usr/bin/env python3
"""Offline authored prompts and a conservative balance plan. No env reads or HTTP."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = [
    ('Coral', 'bubble', 'soft coral bells and two buoyant watery syllables'),
    ('Moss', 'sprout', 'a shy woodwind coo with a tiny leafy rustle'),
    ('Iris', 'spark', 'rounded glass tones with a lilting three-note answer'),
    ('Tide', 'bubble', 'a low liquid burble followed by a soft rising whistle'),
    ('Orbit', 'spark', 'a bouncy round electronic pip with a springy wobble'),
    ('Plum', 'pebble', 'a velvety low hum and one warm hollow wooden pop'),
    ('Poppy', 'bubble', 'a light bubbly trill ending in a playful double pop'),
    ('Inky', 'pebble', 'a soft bassy murmur with a dry delicate click'),
    ('Pebble', 'pebble', 'rounded hollow ceramic notes and a warm breathy coo'),
    ('Nori', 'sprout', 'a mellow reed chirp with a little descending sigh'),
    ('Ember', 'spark', 'a warm rounded shimmer and a bright little upward pip'),
    ('Wisp', 'sprout', 'an airy gentle flute murmur ending in one tiny squeak'),
]
CUES = [
    ('hello', 'greet', 'a warm little greeting'),
    ('delight', 'play', 'a pleased playful giggle'),
    ('rest', 'rest', 'a comfortable sleepy sigh'),
    ('blink', 'blink', 'a tiny soft surprised blink'),
    ('curiosity', 'look', 'a questioning curious chirp'),
    ('idle', 'idle', 'a quiet contented idle murmur'),
    ('catch', 'play', 'a happy little catch of a toy ball'),
    ('company', 'rest', 'a gentle reassuring coo to a nearby little friend'),
]


def requests(variants=1):
    if type(variants) is not int or not 1 <= variants <= 3:
        raise ValueError('Prepare 1–3 authored base variants per cue.')
    result = []
    # Round robin gives every Fonster a hello before adding more events.
    for variant in range(variants):
        for cue, event, expression in CUES:
            for name, family, motif in CHARACTERS:
                text = (f'One original imaginary small creature sound, {expression}. '
                        f'Its distinctive timbre is {motif}. Variation {variant + 1}, '
                        'gentle and expressive, one second, quiet, no words, no human voice, '
                        'no music, no harsh transients, a clean isolated one-shot with silence at both ends.')
                request = {'text': text, 'duration_seconds': 1.0, 'prompt_influence': 0.6,
                           'loop': False, 'model_id': 'eleven_text_to_sound_v2'}
                digest = hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()
                result.append({'asset_id': f'{name.lower()}_{cue}_{variant + 1}_{digest[:12]}',
                               'character': name, 'family': family, 'event': event, 'cue': cue,
                               'request': request, 'request_sha256': digest, 'estimated_credits': 40})
    return result


def remaining_included_credits(metadata, now=None):
    allowed = {'tier', 'status', 'character_count', 'character_limit', 'max_credit_limit_extension', 'checked_at'}
    if set(metadata) != allowed:
        raise ValueError('Supply only the six non-secret subscription fields; no full provider response.')
    if metadata['tier'] not in {'starter', 'creator', 'pro', 'scale', 'business', 'enterprise'} or metadata['status'] != 'active':
        raise ValueError('An active confirmed paid plan is required for commercial sound assets.')
    if type(metadata['max_credit_limit_extension']) is not int or metadata['max_credit_limit_extension'] != 0:
        raise ValueError('Usage-based billing must already be disabled. This tool cannot change billing settings.')
    count, limit = metadata['character_count'], metadata['character_limit']
    if any(type(x) is not int or x < 0 for x in [count, limit]) or count > limit:
        raise ValueError('Invalid included-credit counters.')
    checked = datetime.fromisoformat(metadata['checked_at'].replace('Z', '+00:00'))
    if checked.utcoffset() is None:
        raise ValueError('The subscription snapshot needs a timezone.')
    age = ((now or datetime.now(timezone.utc)) - checked).total_seconds()
    if not 0 <= age <= 900:
        raise ValueError('Confirm subscription and overage metadata again; the snapshot must be less than 15 minutes old.')
    return limit - count


def affordable(items, remaining, attempts=None):
    if type(remaining) is not int or remaining < 0:
        raise ValueError('A nonnegative included-credit balance is required.')
    attempts = attempts or {}
    if any(a.get('actual_credits') is not None and a['actual_credits'] > a['reserved_credits'] for a in attempts.values()):
        raise ValueError('Reconcile an unexpectedly higher charge before planning another batch.')
    uncertain = 0
    for attempt in attempts.values():
        reservation = attempt['reserved_credits']
        if type(reservation) is not int or reservation < 0:
            raise ValueError('Invalid existing reservation; reconcile the ledger first.')
        if attempt.get('actual_credits') is None:
            uncertain += reservation  # May not yet appear in the provider balance.
    if uncertain > remaining:
        raise ValueError('Unreconciled reservations already exceed the included balance.')
    selected, held = [], uncertain
    for item in items:
        existing = attempts.get(item['asset_id'])
        if existing:
            if existing['request_sha256'] != item['request_sha256']:
                raise ValueError('An attempted asset ID has changed prompt content.')
            continue  # Failed and uncertain charged calls are never retried.
        cost = math.ceil(item['request']['duration_seconds'] * 40)
        if held + cost > remaining or len(selected) == 24:
            break
        selected.append(item); held += cost
    return {'version': 1, 'requests': selected, 'reserved_estimate': held - uncertain,
            'held_uncertain_credits': uncertain,
            'included_credits_left_unallocated': remaining - held}


def runtime_voice_variant(public_id, cue, ordinal):
    """Local deterministic playback variation, never a new generated audio asset."""
    value = hashlib.sha256(f'fonsters-voice-v1:{public_id}:{cue}:{ordinal}'.encode()).digest()
    return {'rate': [0.94, 1.0, 1.06][value[0] % 3], 'gain': [0.82, 0.9, 1.0][value[1] % 3],
            'variant_slot': value[2] % 3, 'new_generated_assets': 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', type=Path)
    parser.add_argument('--subscription-metadata', type=Path)
    parser.add_argument('--ledger', type=Path)
    parser.add_argument('--variants', type=int, default=1)
    args = parser.parse_args()
    items = requests(args.variants)
    report = {'mode': 'offline_plan', 'api_calls': 0, 'credentials_read': False, 'generated_base_clips': 0,
              'prepared_base_clips': len(items), 'full_estimated_credits': len(items) * 40,
              'four_family_hello_pilot_credits': 160,
              'license_source': 'https://elevenlabs.io/sound-effects',
              'rate_source': 'https://elevenlabs.io/docs/overview/capabilities/sound-effects',
              'subscription_source': 'https://elevenlabs.io/docs/api-reference/user/subscription/get',
              'budget_authorization': 'existing remaining included credits only; no overage, top-up or plan change',
              'generation_blockers': ['approved existing server job/key scope', 'confirmed paid commercial plan',
                                      'fresh included balance and usage-based billing disabled', 'durable attempt ledger'],
              'version': 1, 'requests': items}
    if args.subscription_metadata:
        balance = remaining_included_credits(json.loads(args.subscription_metadata.read_text()))
        ledger = json.loads(args.ledger.read_text()) if args.ledger else {'attempts': {}}
        report['affordable_next_batch'] = affordable(items, balance, ledger['attempts'])
    if args.write:
        args.write.parent.mkdir(parents=True, exist_ok=True)
        args.write.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'requests'}, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
