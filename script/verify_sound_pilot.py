#!/usr/bin/env python3
"""Offline tests: fake key, account metadata and audio; no provider calls."""
import contextlib
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_sound_pilot as pilot


class PilotTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='fonsters-pilot-tests-')
        self.output = Path(self.folder.name) / 'batch'
        self.calls = 0
        self.metadata = {'tier': 'creator', 'status': 'active', 'character_count': 200,
                         'character_limit': 1000, 'max_credit_limit_extension': 0,
                         'checked_at': datetime.now(timezone.utc).isoformat()}

    def tearDown(self):
        self.folder.cleanup()

    def fake_audio(self, request, credential):
        self.assertEqual(credential, 'offline-test-only')
        self.calls += 1
        return b'ID3offline-fixture', '40'

    def account(self, credential):
        return self.metadata

    def test_default_does_not_prompt_or_read_account_or_key(self):
        with patch.object(pilot.getpass, 'getpass', side_effect=AssertionError()), \
             patch.object(pilot, 'subscription', side_effect=AssertionError()), \
             patch.object(pilot.os, 'getenv', side_effect=AssertionError()), \
             contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(pilot.main([]), 0)
        result = json.loads(stream.getvalue())
        self.assertEqual((result['api_calls'], result['clips'], result['estimated_credits']), (0, 4, 160))

    def test_execute_refuses_non_terminal_before_key_or_network(self):
        with patch.object(pilot.sys.stdin, 'isatty', return_value=False), \
             patch.object(pilot.getpass, 'getpass', side_effect=AssertionError()), \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(pilot.main(['--execute']), 1)

    def test_account_gates_send_no_audio_calls(self):
        for change in [{'max_credit_limit_extension': 1}, {'max_credit_limit_extension': 'unlimited'},
                       {'tier': 'free'}, {'status': 'canceled'}, {'character_limit': 300}]:
            with self.subTest(change=change):
                metadata = {**self.metadata, **change}
                with self.assertRaises(ValueError):
                    pilot.run('offline-test-only', self.output, lambda _: metadata, self.fake_audio)
                self.assertEqual(self.calls, 0)

    def test_verified_pilot_has_durable_reservations_and_no_saved_key(self):
        result = pilot.run('offline-test-only', self.output, self.account, self.fake_audio)
        self.assertEqual((self.calls, result['reserved_credits']), (4, 160))
        self.assertEqual(self.output.stat().st_mode & 0o077, 0)
        for path in self.output.rglob('*'):
            if path.is_file(): self.assertNotIn(b'offline-test-only', path.read_bytes())
        self.assertEqual(set(json.loads((self.output / 'subscription-metadata.json').read_text())),
                         set(pilot.FIELDS) | {'checked_at'})
        pilot.run('offline-test-only', self.output, self.account, self.fake_audio)
        self.assertEqual(self.calls, 4)

    def test_uncertain_call_is_held_and_unaffordable_resume_stops(self):
        def timeout(request, credential):
            self.calls += 1
            raise TimeoutError()
        with self.assertRaises(ValueError): pilot.run('offline-test-only', self.output, self.account, timeout)
        self.metadata['character_limit'] = 300  # 100 remain; 40 uncertain + 120 pending do not fit.
        with self.assertRaises(ValueError): pilot.run('offline-test-only', self.output, self.account, self.fake_audio)
        self.assertEqual(self.calls, 1)

    def test_subscription_read_is_bounded_allowlisted_and_does_not_follow_auth_redirects(self):
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, size):
                self.size = size
                return json.dumps({**self_metadata, 'invoice': {'private': 'discard'},
                                   'xi_api_key': 'discard-this-field'}).encode()
        self_metadata = self.metadata
        response = Response()
        class Opener:
            def open(self, request, timeout):
                self.request = request
                return response
        opener = Opener()
        with patch.object(pilot.urllib.request, 'build_opener', return_value=opener):
            result = pilot.subscription('offline-test-only')
        self.assertEqual(opener.request.full_url, pilot.SUBSCRIPTION)
        self.assertEqual(opener.request.method, 'GET')
        self.assertEqual(response.size, 65537)
        self.assertEqual(set(result), set(pilot.FIELDS) | {'checked_at'})
        self.assertNotIn('discard', json.dumps(result))
        self.assertIsNone(pilot.pipeline.NoCredentialRedirect().redirect_request(None, None, 302, '', {}, 'https://other.test'))


if __name__ == '__main__': unittest.main(verbosity=2)
