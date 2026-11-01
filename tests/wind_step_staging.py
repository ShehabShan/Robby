"""Offline local staging regression suite. Synthetic target; no HTTP/publication."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import stage_wind_step_published as staging
import ingest_wind_step_published as candidate_intake

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}


class StagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.directory = Path(cls.temp.name)
        result = staging.stage(TARGET, enable_local_test=True)
        cls.raw = Path(result["manifest"]).read_bytes()
        cls.good = json.loads(cls.raw)
        cls.place = Path(result["place"]).read_bytes()
        cls.original = cls.directory / "original.rbxl"
        cls.original.write_bytes(cls.place)
        subprocess.run(["lune", "run", "tests/wind_step_staging_package.luau", str(cls.original),
                        str(cls.directory)], cwd=ROOT, check=True, capture_output=True, timeout=30)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.manifest = copy.deepcopy(self.good)
        self.path = self.directory / "manifest.json"
        self.place_path = self.directory / "input.rbxl"

    def review(self, manifest=None, place=None, raw=None, pin=None):
        raw = raw if raw is not None else json.dumps(manifest or self.manifest, allow_nan=False).encode()
        self.path.write_bytes(raw)
        self.place_path.write_bytes(self.place if place is None else place)
        return staging.verify(self.path, pin or staging.sha(raw), self.place_path)

    def test_staging_is_never_release_or_dynamics_acceptance(self):
        result = self.review()
        self.assertEqual(result["status"], "LOCAL_STAGE_VERIFIED_ONLY")
        for field in ("publishReady", "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(result[field], False)
            self.assertIs(self.manifest[field], False)
        self.assertEqual(result["placeSha256"], staging.sha(self.place))

    def test_explicit_enablement_before_build(self):
        with patch.object(staging.candidate, "build", side_effect=AssertionError("must not build")):
            for opt in (False, None, 1, "true"):
                with self.subTest(opt=opt), self.assertRaises(ValueError):
                    staging.stage(TARGET, enable_local_test=opt)

    def test_production_and_invalid_target_before_build(self):
        with patch.object(staging.candidate, "build", side_effect=AssertionError("must not build")):
            for field, value in (("universeId", "10773761715"), ("placeId", "95587500384127"),
                                 ("ownerUserId", "42"), ("universeId", 123456), ("placeId", "01")):
                target = dict(TARGET, **{field: value})
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    staging.stage(target, enable_local_test=True)
                self.manifest["target"] = target
                with self.assertRaises(ValueError):
                    self.review()

    def test_pinned_manifest_required(self):
        for pin in ("0" * 64, "bad", "A" * 64):
            with self.subTest(pin=pin), self.assertRaises(ValueError):
                self.review(pin=pin)

    def test_bounded_strict_json(self):
        for raw in (b'{"schema":1,"schema":1}', b'{"schema":NaN}', b'\xff',
                    b' ' * (staging.MAX_MANIFEST + 1), b'[]', b'{}', b'null'):
            with self.subTest(raw=raw[:30]), self.assertRaises((ValueError, UnicodeError)):
                self.review(raw=raw)

    def test_valid_json_over_manifest_bound_is_refused(self):
        raw = self.raw + b" " * (staging.MAX_MANIFEST + 1 - len(self.raw))
        with self.assertRaisesRegex(ValueError, "byte limit"):
            self.review(raw=raw)

    def test_oversized_place_with_matching_digest_is_refused(self):
        place = b"X" * (staging.MAX_PLACE + 1)
        with self.assertRaisesRegex(ValueError, "place size"):
            self.review(dict(self.good, placeSha256=staging.sha(place)), place)

    def test_schema_readiness_and_open_gates(self):
        changes = {"schema": True, "kind": "WindStep disabled published candidate", "publishReady": True,
                   "releaseEvidenceAccepted": True, "dynamicsAccepted": True, "remaining": [],
                   "sourceRevision": "not-a-revision", "publishedVersion": 1}
        for field, value in changes.items():
            changed = dict(self.good, **{field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.review(changed)
        for field in self.good:
            changed = dict(self.good)
            del changed[field]
            with self.subTest(missing=field), self.assertRaises(ValueError):
                self.review(changed)

    def test_source_and_tooling_provenance(self):
        for field, value in (("sourceHashes", {}), ("generatedServerSha256", "0" * 64),
                             ("toolingHashes", {})):
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.review(dict(self.good, **{field: value}))

    def test_place_bounds_and_digest(self):
        for place in (b"", self.place + b"X", b"X" * (staging.MAX_PLACE + 1)):
            with self.subTest(size=len(place)), self.assertRaises(ValueError):
                self.review(place=place)

    def test_rehashed_hostile_packages_still_fail_exact_rebuild(self):
        fixtures = sorted(self.directory.glob("*.rbxl"))
        tested = 0
        for path in fixtures:
            if path.name in ("original.rbxl", "input.rbxl"):
                continue
            place = path.read_bytes()
            changed = dict(self.good, placeSha256=staging.sha(place))
            with self.subTest(case=path.stem), self.assertRaises(subprocess.CalledProcessError):
                self.review(changed, place)
            tested += 1
        self.assertEqual(tested, 14)

    def test_disabled_candidate_cannot_be_relabeled(self):
        disabled = (ROOT / "build/published-test/WindStepPublishedCandidate.rbxl").read_bytes()
        with self.assertRaises(subprocess.CalledProcessError):
            self.review(dict(self.good, placeSha256=staging.sha(disabled)), disabled)
        with self.assertRaises(ValueError):
            candidate_intake.validate_manifest(self.good, self.place)

    def test_repeat_build_is_identical_and_default_stays_disabled(self):
        result = staging.stage(TARGET, enable_local_test=True)
        self.assertEqual(Path(result["place"]).read_bytes(), self.place)
        self.assertEqual(Path(result["manifest"]).read_bytes(), self.raw)
        default = json.loads((ROOT / "build/published-test/manifest.json").read_bytes())
        self.assertEqual(default["kind"], "WindStep disabled published candidate")
        self.assertIs(default["publishReady"], False)
        subprocess.run(["lune", "run", "tests/wind_step_staging_package.luau", str(self.original),
                        str(self.directory)], cwd=ROOT, check=True, capture_output=True, timeout=30)

    def test_failed_build_leaves_no_old_staging_pair(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(staging, "DIRECTORY", Path(directory)):
            staging.stage(TARGET, enable_local_test=True)
            with patch.object(staging.candidate, "build", side_effect=RuntimeError("synthetic failure")):
                with self.assertRaises(RuntimeError):
                    staging.stage(TARGET, enable_local_test=True)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_cli_requires_opt_in_and_reports_failure(self):
        target_path = self.directory / "target.json"
        target_path.write_text(json.dumps(TARGET))
        proc = subprocess.run([sys.executable, "scripts/stage_wind_step_published.py", "--stage", "--target",
                               str(target_path)], cwd=ROOT, capture_output=True, text=True, timeout=30)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("explicit local enablement required", proc.stderr)


if __name__ == "__main__":
    unittest.main()
