"""SYNTHETIC offline regressions, never Roblox physics or release evidence."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import ingest_wind_step_published as intake
import wind_step_evidence_intake as studio_fixture

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}


def summarize(report):
    computed = intake.calculate(report)
    report.update({k: computed[k] for k in ("passed", "expected", "matrixPassed", "remaining")})


class PublishedIntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        intake.builder.build(TARGET)
        cls.raw_manifest = (ROOT / "build/published-test/manifest.json").read_bytes()
        cls.manifest = json.loads(cls.raw_manifest)
        cls.place = (ROOT / "build/published-test/WindStepPublishedCandidate.rbxl").read_bytes()
        report, _ = studio_fixture.synthetic()
        report["kind"] = "WindStep isolated published dynamics"
        report["target"] = {k: int(TARGET[k]) for k in ("universeId", "placeId", "ownerUserId")}
        report["environment"].update(studio=False, universeId=int(TARGET["universeId"]),
            placeId=int(TARGET["placeId"]), playerUserId=int(TARGET["ownerUserId"]),
            jobId="SYNTHETIC-NOT-A-ROBLOX-JOB", placeVersion=7,
            sourceRevision=cls.manifest["sourceRevision"], sourceHashes=json.dumps(cls.manifest["sourceHashes"]),
            generatedServerSha256=cls.manifest["generatedServerSha256"])
        summarize(report)
        cls.good = report

    def setUp(self):
        self.report = copy.deepcopy(self.good)
        self.manifest = copy.deepcopy(type(self).manifest)

    def invalid(self, report=None, manifest=None, place=None):
        with self.assertRaises((ValueError, OverflowError)):
            intake.review(self.report if report is None else report,
                          self.manifest if manifest is None else manifest,
                          self.place if place is None else place)

    def test_offline_pass_is_never_release_evidence(self):
        result = intake.review(self.report, self.manifest, self.place)
        self.assertEqual(result["status"], "OFFLINE_CANDIDATE_REVIEW")
        self.assertTrue(result["firstSliceReportedPass"])
        self.assertEqual(result["passed"], 106)
        self.assertFalse(result["dynamicsAccepted"])
        self.assertFalse(result["releaseEvidenceAccepted"])
        self.assertIn("death/original-root replacement", result["remaining"])

    def test_studio_intake_remains_strict(self):
        with self.assertRaisesRegex(ValueError, "bad report kind"):
            intake.common.validate_report(self.report, self.manifest)
        self.report["kind"] = "WindStep isolated Studio dynamics"
        self.invalid()

    def test_missing_and_failed_results_recomputed(self):
        self.report["results"].pop()
        self.invalid()
        summarize(self.report)
        result = intake.review(self.report, self.manifest, self.place)
        self.assertFalse(result["firstSliceReportedPass"])
        self.assertEqual(result["missing"], ["lifetime-100"])
        self.report["results"][0]["restored"] = False
        summarize(self.report)
        self.assertIn("travel-auto", intake.review(self.report, self.manifest, self.place)["failed"])

    def test_partial_error_stays_failure(self):
        self.report.update(results=[], runCompleted=False, error="cancelled", cleanup=False)
        summarize(self.report)
        result = intake.review(self.report, self.manifest, self.place)
        self.assertFalse(result["firstSliceReportedPass"])
        self.assertEqual(result["error"], "cancelled")

    def test_environment_cleanup_and_completion_never_bypassed(self):
        for key in ("studio", "server", "running", "optIn", "players"):
            with self.subTest(key=key):
                report = copy.deepcopy(self.good)
                report["environment"][key] = True if key == "studio" else 2 if key == "players" else False
                summarize(report)
                self.assertFalse(intake.review(report, self.manifest, self.place)["firstSliceReportedPass"])
        for key in ("cleanup", "runCompleted"):
            with self.subTest(key=key):
                report = copy.deepcopy(self.good); report[key] = False; summarize(report)
                self.assertFalse(intake.review(report, self.manifest, self.place)["firstSliceReportedPass"])

    def test_target_and_live_identity_binding(self):
        for section, fields in (("target", ("universeId", "placeId", "ownerUserId")),
                                ("environment", ("universeId", "placeId", "playerUserId"))):
            for key in fields:
                for value in (True, "123", 1, None):
                    report = copy.deepcopy(self.good); report[section][key] = value
                    self.invalid(report=report)
        for key, value in (("placeVersion", 0), ("placeVersion", True), ("placeVersion", 2**54),
                           ("jobId", ""), ("jobId", "é" * 65), ("jobId", 12)):
            report = copy.deepcopy(self.good); report["environment"][key] = value; self.invalid(report=report)
        self.report["target"]["extra"] = 1; self.invalid()

    def test_production_and_unconfigured_manifest_refused(self):
        for key, value in (("universeId", "10773761715"), ("placeId", "95587500384127"),
                           ("ownerUserId", "1"), ("universeId", 123456)):
            manifest = copy.deepcopy(self.manifest); manifest["target"][key] = value; self.invalid(manifest=manifest)
        self.manifest["target"] = None; self.invalid()

    def test_no_ready_or_unknown_manifest(self):
        for key, value in (("kind", "WindStep published release"), ("publishReady", True),
                           ("publishReady", 0), ("dynamicsAccepted", True), ("schema", True),
                           ("sourceRevision", "bogus")):
            manifest = copy.deepcopy(self.manifest); manifest[key] = value; self.invalid(manifest=manifest)

    def test_all_source_hashes_and_generated_source_are_bound(self):
        for path in intake.builder.FILES:
            manifest = copy.deepcopy(self.manifest); manifest["sourceHashes"][path] = "0" * 64
            self.invalid(manifest=manifest)
        for action in ("missing", "extra"):
            manifest = copy.deepcopy(self.manifest)
            if action == "missing": manifest["sourceHashes"].pop(intake.builder.FILES[0])
            else: manifest["sourceHashes"]["../../external"] = "0" * 64
            self.invalid(manifest=manifest)
        self.manifest["generatedServerSha256"] = "0" * 64
        self.report["environment"]["generatedServerSha256"] = "0" * 64
        self.invalid()

    def test_report_provenance_is_exact(self):
        for key, value in (("sourceRevision", "0" * 40), ("sourceHashes", "{}"),
                           ("sourceHashes", '{"duplicate":1,"duplicate":2}'),
                           ("generatedServerSha256", "0" * 64)):
            report = copy.deepcopy(self.good); report["environment"][key] = value; self.invalid(report=report)

    def test_exact_place_bytes_required(self):
        self.invalid(place=self.place + b"corrupt")
        self.invalid(place=b"")
        self.invalid(place=b"x" * (intake.MAX_PLACE + 1))
        self.manifest["placeSha256"] = "0" * 64; self.invalid()

    def test_counters_gates_and_sample_consistency(self):
        for key, value in (("passed", 107), ("expected", True), ("matrixPassed", False),
                           ("dynamicsAccepted", True), ("remaining", []), ("error", "error")):
            report = copy.deepcopy(self.good); report[key] = value; self.invalid(report=report)
        self.report["results"][0]["samples"][0]["dt"] = .03; self.invalid()

    def test_malformed_rows_and_bounds(self):
        for key, value in (("schema", True), ("environment", []), ("results", {}),
                           ("results", [None]), ("results", self.good["results"] * 2)):
            report = copy.deepcopy(self.good); report[key] = value; self.invalid(report=report)
        for key, value in (("distance", float("nan")), ("distance", True), ("pairs", 1.5),
                           ("samples", [{}] * 129), ("name", "other")):
            report = copy.deepcopy(self.good); report["results"][0][key] = value; self.invalid(report=report)
        self.report["results"][1] = self.report["results"][0]; self.invalid()

    def test_strict_loading(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.json"
            for raw in (b'{"a":1,"a":2}', b'{"a":NaN}', b'{"a":Infinity}', b'\xff',
                        b'"' + b'x' * intake.MAX_REPORT + b'"'):
                path.write_bytes(raw)
                with self.assertRaises((ValueError, UnicodeError)):
                    intake.load(path, intake.MAX_REPORT)
            raw = b'"' + b'x' * (intake.MAX_REPORT - 2) + b'"'
            path.write_bytes(raw)
            self.assertEqual(len(intake.load(path, intake.MAX_REPORT)[1]), intake.MAX_REPORT)
        report = copy.deepcopy(self.good); report["padding"] = "x" * intake.MAX_REPORT; self.invalid(report=report)
        manifest = copy.deepcopy(self.manifest); manifest["padding"] = "x" * intake.MAX_MANIFEST; self.invalid(manifest=manifest)

    def test_cli_pinned_manifest_explicit_scope_and_readonly(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory); report = base / "report.json"; manifest = base / "manifest.json"; place = base / "test.rbxl"
            report.write_text(json.dumps(self.good)); manifest.write_bytes(self.raw_manifest); place.write_bytes(self.place)
            inputs = {p: p.read_bytes() for p in (report, manifest, place)}
            pin = hashlib.sha256(self.raw_manifest).hexdigest()
            cmd = [sys.executable, "-B", "scripts/ingest_wind_step_published.py", str(report),
                   "--manifest", str(manifest), "--place", str(place), "--manifest-sha256", pin]
            def run(extra):
                return subprocess.run(cmd + extra, cwd=ROOT, text=True, capture_output=True, timeout=30)
            self.assertEqual(run([]).returncode, 2)
            result = run(["--candidate-review"])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(json.loads(result.stdout)["releaseEvidenceAccepted"])
            manifest.write_bytes(self.raw_manifest + b" ")
            self.assertEqual(run(["--candidate-review"]).returncode, 2)
            manifest.write_bytes(self.raw_manifest)
            for p, raw in inputs.items(): self.assertEqual(p.read_bytes(), raw)
            partial = copy.deepcopy(self.good); partial["runCompleted"] = False; summarize(partial)
            report.write_text(json.dumps(partial)); self.assertEqual(run(["--candidate-review"]).returncode, 1)
            report.write_bytes(b'[]'); result = run(["--candidate-review"])
            self.assertEqual(result.returncode, 2); self.assertEqual(json.loads(result.stdout)["status"], "INVALID_OR_UNVERIFIABLE")


if __name__ == "__main__":
    unittest.main()
