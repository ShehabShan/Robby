"""Offline source transformation refuses drift; no API calls."""
import importlib.util
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import build_wind_step_published as builder

class BuilderTests(unittest.TestCase):
    def test_body_exact_except_reviewed_seams(self):
        studio = (ROOT / builder.STUDIO).read_text()
        generated = builder.generated_source(studio, (ROOT / builder.HEADER).read_text())
        self.assertIn('Policy.finish(target, environment, rows, cleanup, Evidence)', generated)
        self.assertIn('player.UserId == target.ownerUserId', generated)
        self.assertIn('sourceHashes = script:GetAttribute("SourceHashes")', generated)
        for marker in ('local Driver =', 'local ok, failure =', '-- Independent releases;'):
            self.assertEqual(generated.count(marker), 1)
        # Full execution/cleanup tail is unchanged except final classifier.
        start = studio.index('local ok, failure =')
        expected = studio[start:].replace('Evidence.finish(environment, rows, cleanup)', 'Policy.finish(target, environment, rows, cleanup, Evidence)')
        self.assertTrue(generated.endswith(expected))

    def test_source_drift_refuses(self):
        source = (ROOT / builder.STUDIO).read_text()
        for marker in ('local player = Players:GetPlayers()[1]\n', 'Evidence.finish(environment, rows, cleanup)', 'assert(#Players:GetPlayers() == 1 and player.Character == character and humanoid.Health > 0, "player changed")'):
            for changed in (source.replace(marker, ''), source + marker):
                with self.assertRaises(ValueError):
                    builder.generated_source(changed, '')

    def test_production_refused_before_build(self):
        for field, value in (('universeId','10773761715'), ('placeId','95587500384127')):
            target = {'schema':1,'kind':'Robby isolated published test','universeId':'123','placeId':'456','ownerUserId':'7738981129'}
            target[field] = value
            with self.assertRaises(ValueError):
                builder.build(target)

if __name__ == '__main__':
    unittest.main()
