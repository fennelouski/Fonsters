import unittest
from datetime import datetime, timezone, timedelta
from prepare_personal_sound_bank import requests, remaining_included_credits, affordable, runtime_voice_variant
from sound_pipeline import plan
import tempfile
import json
from pathlib import Path


class PersonalBankTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 7, tzinfo=timezone.utc)
        self.meta = dict(tier='creator', status='active', character_count=500, character_limit=1000,
                         max_credit_limit_extension=0, checked_at=self.now.isoformat())

    def test_unique_prompts_and_pipeline_compatibility(self):
        items = requests()
        self.assertEqual(len(items), 96)
        self.assertEqual(len({i['request_sha256'] for i in items}), 96)
        self.assertEqual({i['character'] for i in items[:12]}, {i['character'] for i in items})
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'plan.json'
            path.write_text(json.dumps({'version': 1, 'requests': items}))
            self.assertEqual(len(plan(path)), 24)
        self.assertEqual(len(requests(3)), 288)

    def test_subscription_no_overage_or_unknown_plan(self):
        self.assertEqual(remaining_included_credits(self.meta, self.now), 500)
        for key, values in [('max_credit_limit_extension', [1, 'unlimited', False]),
                            ('tier', ['free', 'unknown']), ('status', ['past_due']),
                            ('character_count', [-1, 1001, True])]:
            for value in values:
                with self.assertRaises(ValueError):
                    remaining_included_credits({**self.meta, key: value}, self.now)
        with self.assertRaises(ValueError):
            remaining_included_credits({**self.meta, 'xi_api_key': 'never-read'}, self.now)
        with self.assertRaises(ValueError):
            remaining_included_credits(self.meta, self.now + timedelta(minutes=16))

    def test_reservations_skip_uncertain_attempts(self):
        items = requests()
        self.assertEqual(len(affordable(items, 159)['requests']), 3)
        self.assertEqual(len(affordable(items, 0)['requests']), 0)
        uncertain = {items[0]['asset_id']: {'request_sha256': items[0]['request_sha256'], 'reserved_credits': 40, 'actual_credits': None}}
        batch = affordable(items, 80, uncertain)
        self.assertEqual([i['asset_id'] for i in batch['requests']], [items[1]['asset_id']])
        self.assertEqual(batch['held_uncertain_credits'], 40)
        self.assertEqual(batch['reserved_estimate'], 40)
        self.assertEqual(len(affordable(items, 10_000)['requests']), 24)
        with self.assertRaises(ValueError):
            affordable(items, 39, uncertain)
        uncertain[items[0]['asset_id']]['actual_credits'] = 41
        with self.assertRaises(ValueError):
            affordable(items, 1000, uncertain)

    def test_runtime_variants_are_local_not_new_assets(self):
        variants = [runtime_voice_variant('public-demo', 'hello', i) for i in range(100)]
        self.assertEqual(variants, [runtime_voice_variant('public-demo', 'hello', i) for i in range(100)])
        self.assertTrue(all(v['new_generated_assets'] == 0 and .94 <= v['rate'] <= 1.06 and .82 <= v['gain'] <= 1 for v in variants))


if __name__ == '__main__':
    unittest.main()
