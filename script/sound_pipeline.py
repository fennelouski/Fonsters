#!/usr/bin/env python3
"""Offline-first Fonsters sound curation. Uses Python and existing audio tools only.

The generate command is a dry run unless --execute AND an explicit credit cap and
commercial plan are supplied. Execute belongs in an approved server runtime where
ELEVENLABS_API_KEY already exists; never put credentials in arguments or this repo.
"""
import argparse
import array
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
REQUESTS = ROOT / 'docs/prototype/sound-audition/requests.json'
API = 'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128'
LICENSE = 'https://elevenlabs.io/sound-effects'
RATE_SOURCE = 'https://elevenlabs.io/docs/overview/capabilities/sound-effects'
SCHEMA_SOURCE = 'https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert'
CREDITS_PER_SECOND = 40


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def plan(path, event=None, family=None, limit=24):
    document = json.loads(path.read_text())
    if document.get('version') != 1 or not 1 <= limit <= 24:
        raise ValueError('Use a version 1 request list and a limit from 1 to 24.')
    result, ids = [], set()
    for item in document['requests']:
        asset_id = item['asset_id']
        if not re.fullmatch(r'[a-z0-9_]{1,80}', asset_id) or asset_id in ids:
            raise ValueError('Asset IDs must be unique safe filenames.')
        ids.add(asset_id)
        request = item['request']
        if request.get('model_id') != 'eleven_text_to_sound_v2' or request.get('loop') is not False:
            raise ValueError('This curated batch uses one-shot Sound Effects v2 only.')
        duration = request['duration_seconds']
        if not isinstance(duration, (int, float)) or not math.isfinite(duration) or not .5 <= duration <= 3:
            raise ValueError('This curated batch is limited to 0.5–3 seconds per clip.')
        if not 0 <= request['prompt_influence'] <= 1 or not isinstance(request['text'], str) or not request['text'].strip():
            raise ValueError('Invalid authored prompt or influence.')
        if item['event'] not in ('greet', 'play', 'rest', 'blink', 'look', 'idle') or item['family'] not in ('pebble', 'bubble', 'sprout', 'spark'):
            raise ValueError('Unknown event or palette family.')
        if event and item['event'] != event or family and item['family'] != family:
            continue
        result.append({**item, 'request_sha256': digest(json.dumps(request, sort_keys=True).encode()),
                       'estimated_credits': math.ceil(duration * CREDITS_PER_SECOND)})
    return result[:limit]


def dry_report(items):
    # Intentionally does not inspect credentials, initialize HTTP, or write a ledger.
    return {'mode': 'dry_run', 'api_calls': 0, 'credentials_read': False,
            'clips': len(items), 'estimated_credits': sum(i['estimated_credits'] for i in items),
            'estimate_rate': CREDITS_PER_SECOND, 'rate_source': RATE_SOURCE,
            'schema_source': SCHEMA_SOURCE, 'license_source': LICENSE,
            'estimate_checked': '2026-10-07', 'asset_ids': [i['asset_id'] for i in items],
            'next': 'Confirm a commercial paid plan, sound-effects key scope and an explicit credit cap. Keep the key in its approved server runtime.'}


class NoCredentialRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None  # Never forward an authenticated request to another URL.


def post(request, credential):
    payload = json.dumps(request).encode()
    req = urllib.request.Request(API, data=payload, method='POST',
        headers={'xi-api-key': credential, 'Content-Type': 'application/json', 'Accept': 'audio/mpeg'})
    opener = urllib.request.build_opener(NoCredentialRedirect())
    with opener.open(req, timeout=60) as response:
        data = response.read(10 * 1024 * 1024 + 1)
        if len(data) > 10 * 1024 * 1024:
            raise ValueError('Audio exceeded the per-clip size bound.')
        return data, response.headers.get('character-cost')


def generate(items, output, credit_cap, paid_plan, credential, transport=post):
    output.mkdir(parents=True, exist_ok=True)
    with (output / 'batch.lock').open('a') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise ValueError('Another batch owns this ledger; no request sent.') from None
        return _generate(items, output, credit_cap, paid_plan, credential, transport)


def _generate(items, output, credit_cap, paid_plan, credential, transport):
    if not credential or not paid_plan.strip() or not 0 < credit_cap <= 100_000:
        raise ValueError('An approved runtime credential, named commercial paid plan and bounded credit cap are required.')
    ledger_path = output / 'generation-ledger.json'
    ledger = json.loads(ledger_path.read_text()) if ledger_path.exists() else {'version': 1, 'attempts': {}}
    if ledger.get('version') != 1:
        raise ValueError('Unrecognized ledger; preserve it and use another output directory.')
    if ledger.get('paid_plan', paid_plan) != paid_plan:
        raise ValueError('Use the same approved account plan when resuming a batch.')
    ledger['paid_plan'] = paid_plan
    attempts = ledger['attempts']
    if any(a.get('actual_credits') is not None and a['actual_credits'] > a['reserved_credits'] for a in attempts.values()):
        raise ValueError('A prior provider charge exceeded its estimate; this batch remains held for review.')
    reserved = sum(a['reserved_credits'] for a in attempts.values())
    pending = []
    for item in items:
        previous = attempts.get(item['asset_id'])
        if previous and previous['request_sha256'] != item['request_sha256']:
            raise ValueError('Prompt changed for an attempted asset; review it and assign a new ID.')
        if not previous:
            pending.append(item)
    # Reject the full batch before any request. Failed/ambiguous requests retain reservations.
    if reserved + sum(i['estimated_credits'] for i in pending) > credit_cap:
        raise ValueError('Batch exceeds the approved credit reservation cap; no request sent.')
    for item in pending:
        asset_id = item['asset_id']
        raw_path = output / 'raw' / (asset_id + '.mp3')
        if raw_path.exists():
            raise ValueError('Existing audio without a matching ledger must be reviewed; no overwrite.')
        record = {'status': 'in_flight', 'request_sha256': item['request_sha256'],
            'reserved_credits': item['estimated_credits'], 'actual_credits': None,
            'provider': 'ElevenLabs', 'model': item['request']['model_id'],
            'authored_prompt': item['request']['text'], 'family': item['family'], 'event': item['event'],
            'generated_at_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'license': {'url': LICENSE, 'checked_date': '2026-10-07', 'paid_plan_confirmed_by_operator': paid_plan},
            'audition_approved': False}
        attempts[asset_id] = record
        write_json(ledger_path, ledger)  # Persist BEFORE the billable call.
        try:
            audio, cost = transport(item['request'], credential)
            actual = float(cost) if cost is not None else None
            if actual is not None and (not math.isfinite(actual) or actual < 0):
                actual = None
            record['actual_credits'] = actual
            record['cost_source'] = 'character-cost header' if actual is not None else 'estimate only; reconcile with provider'
            raw_path.parent.mkdir(parents=True, exist_ok=True)
            raw_path.write_bytes(audio)
            record['raw_path'] = str(raw_path.relative_to(output))
            record['sha256'] = digest(audio)
            record['status'] = 'generated_needs_qa_and_audition'
            write_json(ledger_path, ledger)
            if actual is not None and actual > record['reserved_credits']:
                raise ValueError('Provider charge exceeded its estimate; stop and review the cap before further calls.')
        except urllib.error.HTTPError as error:
            # Never print provider bodies, request headers or credential-bearing errors.
            record['status'] = 'failed_http_no_automatic_retry'; record['http_status'] = error.code
            write_json(ledger_path, ledger)
            raise ValueError('Provider returned HTTP ' + str(error.code) + '; stopped. Reservation retained; review provider usage before any retry.') from None
        except ValueError:
            if record['status'] == 'in_flight':
                record['status'] = 'ambiguous_no_automatic_retry'; write_json(ledger_path, ledger)
            raise
        except Exception:
            record['status'] = 'ambiguous_no_automatic_retry'; write_json(ledger_path, ledger)
            raise ValueError('Request or audio save failed; stopped. Reservation retained; inspect provider usage before any retry.') from None
    return {'mode': 'execute', 'attempts': len(attempts), 'new_requests': len(pending),
            'reserved_credits': sum(a['reserved_credits'] for a in attempts.values()),
            'known_actual_credits': sum(a['actual_credits'] or 0 for a in attempts.values()),
            'unknown_cost_attempts': sum(a['actual_credits'] is None for a in attempts.values()),
            'ledger': str(ledger_path), 'audition_approved': False}


def normalize(source, destination):
    """PCM RMS -24 dBFS target, peak <= -6 dBFS, 10ms fades. This is not LUFS."""
    with wave.open(str(source), 'rb') as wav:
        if wav.getsampwidth() != 2 or wav.getnchannels() != 1 or wav.getframerate() != 22050:
            raise ValueError('QA expects 22050 Hz mono signed 16-bit PCM WAV.')
        samples = array.array('h', wav.readframes(wav.getnframes()))
        if sys.byteorder != 'little': samples.byteswap()
    duration = len(samples) / 22050
    if not .15 <= duration <= 3.5 or not samples:
        raise ValueError('Quarantine: clip duration outside the curated one-shot range.')
    peak = max(abs(s) for s in samples) / 32768
    rms = math.sqrt(sum((s / 32768) ** 2 for s in samples) / len(samples))
    if rms < .0003 or peak < .003 or sum(abs(s) >= 32760 for s in samples) / len(samples) > .001:
        raise ValueError('Quarantine: silent or clipped source.')
    gain = min(10 ** (-24 / 20) / rms, 10 ** (-6 / 20) / peak, 4)
    fade = min(220, len(samples) // 4)
    result = array.array('h', (int(s * gain * min(1, i / fade, (len(samples) - 1 - i) / fade)) for i, s in enumerate(samples)))
    out_peak = max(abs(s) for s in result) / 32768
    out_rms = math.sqrt(sum((s / 32768) ** 2 for s in result) / len(result))
    destination.parent.mkdir(parents=True, exist_ok=True)
    if sys.byteorder != 'little': result.byteswap()
    with wave.open(str(destination), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(22050); wav.writeframes(result.tobytes())
    return {'duration_seconds': duration, 'source_peak_dbfs': 20 * math.log10(peak),
            'normalized_peak_dbfs': 20 * math.log10(max(out_peak, 1e-9)),
            'normalized_rms_dbfs': 20 * math.log10(max(out_rms, 1e-9)), 'gain': gain,
            'sha256': digest(destination.read_bytes()), 'audition_approved': False,
            'review': 'Audition for harshness, unwanted speech/music and character fit; automated PCM QA cannot assess these.'}


def curate(output):
    ledger_path = output / 'generation-ledger.json'
    ledger = json.loads(ledger_path.read_text())
    reviewed = 0
    for asset_id, record in ledger['attempts'].items():
        if record['status'] != 'generated_needs_qa_and_audition': continue
        if not re.fullmatch(r'[a-z0-9_]{1,80}', asset_id) or record['raw_path'] != 'raw/' + asset_id + '.mp3':
            raise ValueError('Invalid ledger path; no asset touched.')
        source = output / record['raw_path']
        decoded = output / 'decoded' / (asset_id + '.wav')
        destination = output / 'normalized' / (asset_id + '.wav')
        decoded.parent.mkdir(parents=True, exist_ok=True)
        try:
            if digest(source.read_bytes()) != record['sha256'] or destination.exists():
                raise ValueError('Source changed or normalized asset already exists; review before replacing anything.')
            decoder = 'afconvert'
            try:
                subprocess.run(['/usr/bin/afconvert', str(source), str(decoded), '-f', 'WAVE', '-d', 'LEI16@22050', '-c', '1'],
                               check=True, capture_output=True, timeout=30)
            except (OSError, subprocess.SubprocessError):
                encoder = shutil.which('ffmpeg')
                if not encoder: raise ValueError('Native decoder failed and no existing fallback is available.') from None
                decoder = 'ffmpeg (existing fallback after native decoder failed)'
                subprocess.run([encoder, '-loglevel', 'error', '-y', '-i', str(source), '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', str(decoded)],
                               check=True, capture_output=True, timeout=30)
            record['quality'] = normalize(decoded, destination)
            record['quality']['decoder'] = decoder
            record['normalized_path'] = str(destination.relative_to(output))
            record['status'] = 'qa_passed_needs_human_audition'
            reviewed += 1
        except Exception:
            record['status'] = 'quarantined'; record['review'] = 'Decode or PCM quality check failed. Original audio preserved; no automatic regeneration.'
        write_json(ledger_path, ledger)
    return {'qa_passed': reviewed, 'ledger': str(ledger_path), 'production_assets_written': False}


class PaletteSelector:
    """Only approved assets; per-character cooldown and last-two avoidance."""
    def __init__(self, catalog, palettes, rng=None):
        self.catalog, self.palettes, self.rng = catalog, palettes, rng or random.Random()
        self.recent, self.last_play = {}, {}

    def choose(self, character, event, now=None):
        now = time.monotonic() if now is None else now
        if now - self.last_play.get(character, -math.inf) < 1.2: return None
        family = self.palettes.get(character)
        candidates = [a for a in self.catalog if a.get('audition_approved') is True and a['family'] == family and a['event'] == event]
        recent = self.recent.get(character, [])
        fresh = [a for a in candidates if a['asset_id'] not in recent]
        # Small pools avoid the last clip; an exhausted one-clip pool stays silent.
        if not fresh: fresh = [a for a in candidates if not recent or a['asset_id'] != recent[-1]]
        if not fresh: return None
        chosen = self.rng.choice(fresh)
        self.recent[character] = (recent + [chosen['asset_id']])[-2:]
        self.last_play[character] = now
        return chosen


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    batch = commands.add_parser('generate', help='Dry run by default. Execute only in an approved server runtime.')
    batch.add_argument('--requests', type=Path, default=REQUESTS)
    batch.add_argument('--event', choices=['greet', 'play', 'rest', 'blink', 'look', 'idle'])
    batch.add_argument('--family', choices=['pebble', 'bubble', 'sprout', 'spark'])
    batch.add_argument('--limit', type=int, default=24)
    batch.add_argument('--output', type=Path, default=ROOT / '.prototype-build/sound-audition')
    batch.add_argument('--execute', action='store_true')
    batch.add_argument('--approved-credits', type=int)
    batch.add_argument('--commercial-paid-plan')
    qa = commands.add_parser('curate', help='Offline decode and normalization; never calls the provider.')
    qa.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'curate': result = curate(args.output)
        else:
            items = plan(args.requests, args.event, args.family, args.limit)
            if not args.execute: result = dry_report(items)
            else:
                # Only after authorization flags and cost validation; dry runs never touch env.
                if not args.approved_credits or not args.commercial_paid_plan:
                    raise ValueError('Execute requires --approved-credits and --commercial-paid-plan. No credential read or API call occurred.')
                if sum(i['estimated_credits'] for i in items) > args.approved_credits:
                    raise ValueError('Batch exceeds the approved estimate; no credential read or API call occurred.')
                result = generate(items, args.output, args.approved_credits, args.commercial_paid_plan, os.getenv('ELEVENLABS_API_KEY'))
        print(json.dumps(result, indent=2))
        return 0
    except (ValueError, KeyError, OSError, json.JSONDecodeError):
        # Keep errors generic at the CLI boundary; never echo keys or transport bodies.
        print('Stopped: invalid input, missing approval/runtime access, budget constraint, or a recorded generation/quality error. No automatic retry. Inspect the local ledger and documented setup.', file=sys.stderr)
        return 1


if __name__ == '__main__': sys.exit(main())
