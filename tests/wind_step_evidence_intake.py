"""Synthetic intake regressions only. None of these reports came from Roblox."""
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("intake", ROOT / "scripts/ingest_wind_step_evidence.py")
intake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intake)


def synthetic():
    manifest = intake.load(ROOT / "build/WindStepTest.manifest.json")
    report = {
        "schema": 1, "kind": "WindStep isolated Studio dynamics", "cleanup": True,
        "dynamicsAccepted": False, "runCompleted": True,
        "environment": {"studio": True, "running": True, "server": True, "optIn": True,
                        "players": 1, "engine": "SYNTHETIC-NOT-ROBLOX", "placeVersion": 0,
                        "gravity": 196.2, "sourceRevision": manifest["sourceRevision"],
                        "sourceHashes": json.dumps(manifest["sourceHashes"])},
        "results": [],
    }
    for name, kind in intake.KINDS.items():
        distance = 4 if kind == "wall" else 3 if kind == "cancel" else 14
        row = {"name": name, "kind": kind, "committed": True, "clean": True,
               "restored": True, "phaseOK": True, "distance": distance, "maxX": distance,
               "elapsed": .24, "minDt": .02, "maxDt": .02, "pairs": 12,
               "maxYError": 0, "maxYDip": 0, "maxSide": 0, "commandedDistance": distance,
               "lastSpeed": distance / .24, "simulatedSeconds": .24,
               "cancelled": kind == "cancel", "velocityKept": kind == "cancel", "samples": []}
        if not name.startswith("lifetime-"):
            row["samples"] = [{"dt": .02, "t": i * .02, "x": distance * i / 12,
                               "y": 0, "vy": 0, "commandSpeed": distance / .24, "applied": True}
                              for i in range(1, 13)]
        report["results"].append(row)
    summarize(report)
    return report, manifest


def summarize(report):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "report.json"
        path.write_text(json.dumps(report))
        p = subprocess.run(["lune", "run", "scripts/wind_step_evidence.luau", str(path)],
                           cwd=ROOT, check=True, capture_output=True, text=True)
        computed = json.loads(p.stdout)
    report.update({k: computed[k] for k in ("passed", "expected", "matrixPassed", "remaining")})


class IntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.good, cls.manifest = synthetic()

    def setUp(self):
        self.report, self.bundle = copy.deepcopy(self.good), copy.deepcopy(self.manifest)

    def invalid(self, report=None, manifest=None):
        with self.assertRaises((ValueError, OverflowError)):
            intake.review(self.report if report is None else report, self.bundle if manifest is None else manifest)

    def test_first_slice_never_grants_acceptance(self):
        result = intake.review(self.report, self.bundle)
        self.assertEqual(result["status"], "FIRST_SLICE_REPORTED_PASS")
        self.assertFalse(result["dynamicsAccepted"])
        self.assertEqual(result["passed"], 106)
        self.assertIn("death/original-root replacement", result["remaining"])

    def test_missing_case_does_not_hide_behind_pass_counters(self):
        self.report["results"].pop()
        self.invalid()
        summarize(self.report)
        result = intake.review(self.report, self.bundle)
        self.assertEqual(result["status"], "BLOCKED_OR_FAILED")
        self.assertEqual(result["missing"], ["lifetime-100"])

    def test_partial_error_retained(self):
        self.report["results"] = self.report["results"][:1]
        row = self.report["results"][0]
        row.update(committed=False, clean=False, phaseOK=False, pairs=0, samples=[])
        self.report.update(runCompleted=False, error="prepare refused", cleanup=False)
        summarize(self.report)
        result = intake.review(self.report, self.bundle)
        self.assertEqual(result["failed"], ["travel-auto"])
        self.assertEqual(result["error"], "prepare refused")
        self.assertEqual(result["status"], "BLOCKED_OR_FAILED")

    def test_failed_scope_cleanup_completion_and_rows(self):
        for key in ("studio", "server", "running", "optIn", "players"):
            report = copy.deepcopy(self.good)
            report["environment"][key] = 0 if key == "players" else False
            summarize(report)
            self.assertEqual(intake.review(report, self.bundle)["status"], "BLOCKED_OR_FAILED")
        for key in ("cleanup", "runCompleted"):
            report = copy.deepcopy(self.good)
            report[key] = False
            summarize(report)
            self.assertEqual(intake.review(report, self.bundle)["status"], "BLOCKED_OR_FAILED")
        for key in ("committed", "clean", "restored", "phaseOK", "velocityKept"):
            report = copy.deepcopy(self.good)
            report["results"][5][key] = False
            summarize(report)
            self.assertEqual(intake.review(report, self.bundle)["status"], "BLOCKED_OR_FAILED")

    def test_claimed_flags_and_gate_list_not_trusted(self):
        for key, value in (("matrixPassed", False), ("passed", 107), ("expected", 1),
                           ("dynamicsAccepted", True), ("remaining", []), ("error", "failed")):
            report = copy.deepcopy(self.good)
            report[key] = value
            self.invalid(report)

    def test_revision_hash_and_manifest_mismatch(self):
        for key, value in (("sourceRevision", "0" * 40), ("sourceHashes", "{}")):
            report = copy.deepcopy(self.good)
            report["environment"][key] = value
            self.invalid(report)
        for mode in ("missing", "changed", "path"):
            manifest = copy.deepcopy(self.manifest)
            if mode == "missing":
                manifest["sourceHashes"].pop(intake.FILES[0])
            elif mode == "changed":
                manifest["sourceHashes"][intake.FILES[0]] = "0" * 64
            else:
                manifest["sourceHashes"]["../../external"] = "0" * 64
            self.invalid(manifest=manifest)

    def test_malformed_schema_types_and_bounds(self):
        for key, value in (("schema", True), ("results", {}), ("results", [False]),
                           ("results", self.good["results"] * 2), ("cleanup", "true"),
                           ("runCompleted", 1), ("environment", [])):
            report = copy.deepcopy(self.good)
            report[key] = value
            self.invalid(report)
        for key, value in (("name", []), ("name", "other"), ("kind", "wall"),
                           ("pairs", 1.5), ("distance", True), ("distance", "14"),
                           ("distance", math.inf), ("distance", math.nan),
                           ("phaseOK", 1), ("samples", []), ("samples", [{}] * 129)):
            report = copy.deepcopy(self.good)
            report["results"][0][key] = value
            self.invalid(report)
        self.report["results"][1] = copy.deepcopy(self.report["results"][0])
        self.invalid()

    def test_samples_cannot_contradict_aggregates(self):
        for key, value in (("dt", .03), ("t", 1), ("x", 15), ("commandSpeed", 0),
                           ("applied", False), ("vy", "0")):
            report = copy.deepcopy(self.good)
            report["results"][0]["samples"][-1][key] = value
            self.invalid(report)
        for key in ("minDt", "maxDt", "simulatedSeconds", "commandedDistance", "distance", "maxX", "lastSpeed", "elapsed"):
            report = copy.deepcopy(self.good)
            report["results"][0][key] += .001
            self.invalid(report)

    def test_strict_json_and_bounded_input(self):
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '{"x":-Infinity}', '{', '[1,]'):
            with self.assertRaises(ValueError):
                intake.strict_json(text)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "huge.json"
            path.write_bytes(b"{}" + b" " * (intake.MAX_BYTES - 1))
            with self.assertRaises(ValueError):
                intake.load(path)

    def test_build_manifest_matches_place_and_sources(self):
        self.assertEqual(hashlib.sha256((ROOT / "build/WindStepTest.rbxl").read_bytes()).hexdigest(), self.bundle["placeSha256"])
        intake.validate_manifest(self.bundle)

    def test_bundle_is_isolated_and_byte_exact(self):
        with zipfile.ZipFile(ROOT / "build/WindStepTest.zip") as archive:
            self.assertEqual(set(archive.namelist()), {"WindStepTest.rbxl", "WindStepTest.manifest.json", "README.txt"})
            self.assertEqual(archive.read("WindStepTest.rbxl"), (ROOT / "build/WindStepTest.rbxl").read_bytes())
            self.assertEqual(json.loads(archive.read("WindStepTest.manifest.json")), self.bundle)
            readme = archive.read("README.txt")
            self.assertEqual(readme, (ROOT / "tests/studio/WIND_STEP_README.txt").read_bytes())
            self.assertIn(b"dynamicsAccepted stays false", readme)
            self.assertIn(b"Do not publish", readme)

    def test_cli_fail_closed_and_does_not_modify_input(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            manifest = Path(directory) / "manifest.json"
            manifest.write_text(json.dumps(self.bundle))
            for data, expected in ((json.dumps(self.good), 0), ("{}", 2), ("[", 2)):
                report.write_text(data)
                before = report.read_bytes()
                proc = subprocess.run(["python3", "-B", "scripts/ingest_wind_step_evidence.py", str(report),
                                       "--manifest", str(manifest)], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(proc.returncode, expected, proc.stderr + proc.stdout)
                self.assertFalse(json.loads(proc.stdout)["dynamicsAccepted"])
                self.assertEqual(report.read_bytes(), before)
            self.report.update(runCompleted=False, error="fixture failure")
            summarize(self.report)
            report.write_text(json.dumps(self.report))
            proc = subprocess.run(["python3", "-B", "scripts/ingest_wind_step_evidence.py", str(report),
                                   "--manifest", str(manifest)], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 1)
            self.assertEqual(json.loads(proc.stdout)["status"], "BLOCKED_OR_FAILED")


if __name__ == "__main__":
    unittest.main()
