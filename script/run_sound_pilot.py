#!/usr/bin/env python3
"""User-operated, one-time hidden-key handoff. No persisted credential or app integration.

Default: offline dry run. --execute needs a real Terminal and an existing key typed
by its owner. Only subscription metadata is fetched before the four-clip pilot.
"""
import argparse
from datetime import datetime, timezone
import getpass
import json
import os
from pathlib import Path
import stat
import sys
import urllib.error
import urllib.request
import warnings

import prepare_personal_sound_bank as personal
import sound_pipeline as pipeline

SUBSCRIPTION = 'https://api.elevenlabs.io/v1/user/subscription'
PILOT_CAP = 160
DEFAULT_OUTPUT = pipeline.ROOT / 'evidence/elevenlabs-greeting-pilot'
FIELDS = ('tier', 'status', 'character_count', 'character_limit', 'max_credit_limit_extension')


def subscription(credential):
    request = urllib.request.Request(SUBSCRIPTION, method='GET',
        headers={'xi-api-key': credential, 'Accept': 'application/json'})
    opener = urllib.request.build_opener(pipeline.NoCredentialRedirect())
    with opener.open(request, timeout=30) as response:
        raw = response.read(64 * 1024 + 1)
        if len(raw) > 64 * 1024:
            raise ValueError('Subscription response exceeds the size limit.')
        document = json.loads(raw)
    # Discard billing details and any unexpected fields. Never use GET /v1/user.
    metadata = {field: document[field] for field in FIELDS}
    metadata['checked_at'] = datetime.now(timezone.utc).isoformat()
    return metadata


def private_output(folder):
    if folder.is_symlink():
        raise ValueError('The batch folder must be a real private directory.')
    folder.mkdir(parents=True, mode=0o700, exist_ok=True)
    info = folder.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('Use an owned batch directory accessible only to your user.')


def run(credential, output, account_read=subscription, transport=pipeline.post):
    metadata = account_read(credential)
    remaining = personal.remaining_included_credits(metadata)
    items = pipeline.plan(pipeline.REQUESTS, event='greet')
    if len(items) != 4 or sum(item['estimated_credits'] for item in items) != PILOT_CAP:
        raise ValueError('The reviewed pilot must remain four one-second greetings.')
    # The runner also checks its full lifetime reservations under an exclusive lock.
    # Subtract uncertain reservations from the fresh balance before choosing new calls.
    private_output(output)
    ledger_path = output / 'generation-ledger.json'
    attempts = json.loads(ledger_path.read_text())['attempts'] if ledger_path.exists() else {}
    allocation = personal.affordable(items, remaining, attempts)
    pending = [item for item in items if item['asset_id'] not in attempts]
    if len(allocation['requests']) != len(pending):
        raise ValueError('The remaining included balance cannot cover this pilot and held attempts.')
    pipeline.write_json(output / 'subscription-metadata.json', metadata)
    result = pipeline.generate(items, output, PILOT_CAP, metadata['tier'], credential, transport)
    result.update({'included_balance_before': remaining, 'overage_disabled': True,
                   'credential_saved': False, 'production_assets_written': False,
                   'requires_human_audition': True})
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args(argv)
    if not args.execute:
        result = pipeline.dry_report(pipeline.plan(pipeline.REQUESTS, event='greet'))
        result['next'] = 'Open Generate Fonster Sounds.command and enter an existing key in its hidden Terminal prompt.'
        print(json.dumps(result, indent=2))
        return 0
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        print('Stopped: open the launcher in Terminal. Keys cannot be supplied through pipes or arguments.', file=sys.stderr)
        return 1
    credential = None
    os.umask(0o077)
    try:
        print('Fonsters: four original one-second creature greetings (estimated 160 included credits).')
        print('Uses your existing approved budget. Requires an active paid plan and overage already disabled.')
        print('Your key stays in this process; it is not saved, echoed, sent to chat, or put into the app.')
        print('No plan changes, purchases, top-ups, automatic retries or automatic app imports.')
        with warnings.catch_warnings():
            warnings.simplefilter('error', getpass.GetPassWarning)
            credential = getpass.getpass('Existing ElevenLabs key (hidden; Return starts the account check): ')
        if not credential or len(credential) > 512 or any(c.isspace() for c in credential):
            raise ValueError('An existing key is required.')
        result = run(credential, args.output)
        print(json.dumps(result, indent=2))
        print('Saved locally. Review the sounds before adding them to Fonsters.')
        return 0
    except urllib.error.HTTPError as error:
        print(f'Stopped: ElevenLabs account check returned HTTP {error.code}. No automatic retry or billing changes.', file=sys.stderr)
        return 1
    except (ValueError, KeyError, OSError, getpass.GetPassWarning):
        print('Stopped: account access, paid-plan/no-overage/balance check, private storage or generation failed. '
              'Any attempted sound stays reserved in the local ledger; do not automatically retry.', file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print('\nStopped. Any recorded attempt remains reserved; no automatic retry.', file=sys.stderr)
        return 1
    finally:
        credential = None


if __name__ == '__main__':
    sys.exit(main())
