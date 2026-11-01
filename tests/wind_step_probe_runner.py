"""Fail-closed evidence handling; no network access or Roblox engine is emulated here."""
import copy
import os
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
os.environ.setdefault("PROMPTQL_PLATFORM_API_URL", "https://invalid.example")
os.environ.setdefault("PROMPTQL_USER_JWT", "not-a-credential")
import wind_step_probe as probe


def valid_task():
    rows = [{"name": name, "ok": True} for name, count in probe.EXPECTED_CHECKS.items() for _ in range(count)]
    return {"state": "COMPLETE", "output": {"results": [{"kind": "WindStep spatial only", "isServer": True,
            "dynamicsAccepted": False, "failed": 0, "passed": len(rows), "results": rows}]}}


class EvidenceTests(unittest.TestCase):
    def test_complete_matrix(self):
        self.assertTrue(probe.evidence_passed(valid_task()))

    def test_http_completion_not_success(self):
        for bad in (None, {}, "COMPLETE", {"state": "COMPLETE"}, {"state": "COMPLETE", "output": None},
                    {"state": "COMPLETE", "output": {"results": "bad"}}):
            with self.subTest(bad=bad):
                self.assertFalse(probe.evidence_passed(bad))

    def test_terminal_and_error(self):
        for state in ("FAILED", "CANCELLED", "PROCESSING"):
            task = valid_task()
            task["state"] = state
            self.assertFalse(probe.evidence_passed(task))
        task = valid_task()
        task["error"] = {"message": "failure"}
        self.assertFalse(probe.evidence_passed(task))

    def test_every_required_result_is_required(self):
        base = valid_task()
        for index in range(len(base["output"]["results"][0]["results"])):
            task = copy.deepcopy(base)
            report = task["output"]["results"][0]
            report["results"].pop(index)
            report["passed"] -= 1
            self.assertFalse(probe.evidence_passed(task))

    def test_every_failed_result_refuses_even_with_forged_counters(self):
        base = valid_task()
        for index in range(len(base["output"]["results"][0]["results"])):
            task = copy.deepcopy(base)
            task["output"]["results"][0]["results"][index]["ok"] = False
            self.assertFalse(probe.evidence_passed(task))

    def test_wrong_names_duplicates_or_extra_results(self):
        for kind in ("wrong_name", "duplicate", "extra_report"):
            task = valid_task()
            report = task["output"]["results"][0]
            if kind == "wrong_name":
                report["results"][0]["name"] = "not a required check"
            elif kind == "duplicate":
                report["results"].append(report["results"][0])
                report["passed"] += 1
            else:
                task["output"]["results"].append(copy.deepcopy(report))
            self.assertFalse(probe.evidence_passed(task))

    def test_malformed_counts_and_scope(self):
        for field, value in (("passed", 1), ("passed", True), ("failed", False), ("failed", 1),
                             ("dynamicsAccepted", True), ("isServer", False), ("results", [None]),
                             ("results", None), ("results", [{"name": {}, "ok": True}])):
            task = valid_task()
            task["output"]["results"][0][field] = value
            self.assertFalse(probe.evidence_passed(task))


if __name__ == "__main__":
    unittest.main()
