#!/usr/bin/env python3
"""Offline tests only. Fake transport/credential; no provider or account calls."""
import contextlib
import io
import json
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import wave
import sound_pipeline as pipeline


class SoundPipelineTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='fonsters-sound-tests-')
        self.root = Path(self.folder.name)
        self.items = pipeline.plan(pipeline.REQUESTS, event='greet')
        self.calls = 0

    def tearDown(self): self.folder.cleanup()

    def fake(self, request, credential):
        self.calls += 1
        self.assertEqual(credential, 'test-only-placeholder')
        return b'ID3fake-offline-audio', '40'

    def test_dry_run_never_reads_credentials_or_http(self):
        stream = io.StringIO()
        with patch.object(pipeline.os, 'getenv', side_effect=AssertionError('No credential lookup')), \
             patch.object(pipeline.urllib.request, 'urlopen', side_effect=AssertionError('No network')), \
             contextlib.redirect_stdout(stream):
            self.assertEqual(pipeline.main(['generate', '--event', 'greet']), 0)
        report = json.loads(stream.getvalue())
        self.assertEqual((report['clips'], report['estimated_credits'], report['api_calls']), (4, 160, 0))
        self.assertFalse(report['credentials_read'])
        self.assertEqual(pipeline.dry_report(pipeline.plan(pipeline.REQUESTS))['estimated_credits'], 960)

    def test_budget_resume_hash_and_cost_accounting(self):
        with self.assertRaises(ValueError):
            pipeline.generate(self.items, self.root, 159, 'test-paid-plan', 'test-only-placeholder', self.fake)
        self.assertEqual(self.calls, 0)
        report = pipeline.generate(self.items, self.root, 160, 'test-paid-plan', 'test-only-placeholder', self.fake)
        self.assertEqual((self.calls, report['reserved_credits'], report['known_actual_credits']), (4, 160, 160))
        pipeline.generate(self.items, self.root, 160, 'test-paid-plan', 'test-only-placeholder', self.fake)
        self.assertEqual(self.calls, 4, 'Resume must not regenerate attempted assets')
        ledger_text = (self.root / 'generation-ledger.json').read_text()
        self.assertNotIn('test-only-placeholder', ledger_text)
        self.assertTrue(all(not a['audition_approved'] for a in json.loads(ledger_text)['attempts'].values()))
        changed = [{**self.items[0], 'request_sha256': 'changed'}]
        with self.assertRaises(ValueError):
            pipeline.generate(changed, self.root, 160, 'test-paid-plan', 'test-only-placeholder', self.fake)
        self.assertEqual(self.calls, 4)

    def test_timeout_and_http_failures_are_never_automatically_retried(self):
        for failure in [TimeoutError(), urllib.error.HTTPError('fake', 429, 'fake', {}, None)]:
            output = self.root / type(failure).__name__
            def broken(request, credential):
                self.calls += 1
                raise failure
            with self.assertRaises(ValueError):
                pipeline.generate(self.items, output, 160, 'test-paid-plan', 'test-only-placeholder', broken)
            before = self.calls
            ledger = json.loads((output / 'generation-ledger.json').read_text())
            self.assertEqual(next(iter(ledger['attempts'].values()))['reserved_credits'], 40)
            self.assertEqual(len(ledger['attempts']), 1)
            # Resuming just the attempted clip skips it, including ambiguous requests.
            pipeline.generate(self.items[:1], output, 160, 'test-paid-plan', 'test-only-placeholder', broken)
            self.assertEqual(self.calls, before)

    def test_unexpected_provider_cost_holds_batch(self):
        def costly(request, credential):
            self.calls += 1
            return b'ID3fake', '50'
        for _ in range(2):
            with self.assertRaises(ValueError):
                pipeline.generate(self.items, self.root, 160, 'test-paid-plan', 'test-only-placeholder', costly)
        self.assertEqual(self.calls, 1)

    def test_pcm_normalization_and_quarantine(self):
        source = next((pipeline.ROOT / 'Fonsters/Playroom/Sounds').glob('*.wav'))
        target = self.root / 'normalized.wav'
        quality = pipeline.normalize(source, target)
        self.assertLessEqual(quality['normalized_peak_dbfs'], -5.99)
        self.assertFalse(quality['audition_approved'])
        with wave.open(str(target)) as wav:
            self.assertEqual((wav.getframerate(), wav.getnchannels(), wav.getsampwidth()), (22050, 1, 2))
            data = wav.readframes(wav.getnframes())
            self.assertEqual(data[:2], b'\0\0'); self.assertEqual(data[-2:], b'\0\0')
        silence = self.root / 'silent.wav'
        with wave.open(str(silence), 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(22050); wav.writeframes(bytes(22050 * 2))
        with self.assertRaises(ValueError): pipeline.normalize(silence, self.root / 'rejected.wav')
        self.assertFalse((self.root / 'rejected.wav').exists())

    def test_palette_tags_cooldown_and_repeat_avoidance(self):
        palette = json.loads((pipeline.ROOT / 'docs/prototype/sound-audition/palettes.json').read_text())['character_families']
        catalog = [{'asset_id': str(i), 'family': 'sprout', 'event': 'greet', 'audition_approved': True} for i in range(3)]
        catalog += [{'asset_id': 'unreviewed', 'family': 'sprout', 'event': 'greet', 'audition_approved': False}]
        picker = pipeline.PaletteSelector(catalog, palette, random.Random(7))
        choices = [picker.choose('Moss', 'greet', now=i * 2)['asset_id'] for i in range(30)]
        for i in range(2, len(choices)): self.assertNotIn(choices[i], choices[i - 2:i])
        self.assertIsNone(picker.choose('Moss', 'greet', now=58.1))
        self.assertIsNone(picker.choose('Moss', 'play', now=60))
        self.assertIsNone(picker.choose('Coral', 'greet', now=60))
        self.assertNotIn('unreviewed', choices)

    def test_existing_mac_decoder_and_curation(self):
        encoder = shutil.which('ffmpeg')
        if not encoder or not Path('/usr/bin/afconvert').exists():
            self.skipTest('Optional existing encoder/Mac decoder unavailable; no install.')
        source = next((pipeline.ROOT / 'Fonsters/Playroom/Sounds').glob('*.wav'))
        raw = self.root / 'raw/offline_fixture.mp3'
        raw.parent.mkdir(parents=True)
        subprocess.run([encoder, '-loglevel', 'error', '-i', str(source), '-c:a', 'libmp3lame', '-b:a', '128k', str(raw)],
                       check=True, capture_output=True, timeout=30)
        pipeline.write_json(self.root / 'generation-ledger.json', {'version': 1, 'attempts': {'offline_fixture': {
            'status': 'generated_needs_qa_and_audition', 'provider': 'offline_test_fixture',
            'raw_path': 'raw/offline_fixture.mp3', 'sha256': pipeline.digest(raw.read_bytes()),
            'audition_approved': False}}})
        result = pipeline.curate(self.root)
        self.assertEqual(result['qa_passed'], 1)
        ledger = json.loads((self.root / 'generation-ledger.json').read_text())
        record = ledger['attempts']['offline_fixture']
        self.assertEqual(record['status'], 'qa_passed_needs_human_audition')
        self.assertFalse(record['audition_approved'])
        self.assertTrue(raw.exists()); self.assertTrue((self.root / record['normalized_path']).exists())


if __name__ == '__main__': unittest.main(verbosity=2)
