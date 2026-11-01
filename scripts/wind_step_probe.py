"""S89: run the production spatial adapter on an unpublished Saved place, from clean main.
Usage: python3 scripts/wind_step_probe.py [--version N] [--output build/wind-step-probe.json]
Without --version, build with check.sh first. Never publishes. Nonzero exit on failed/incomplete evidence.
"""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import sys

# Importing the runner must not dirty a clean checkout with bytecode.
sys.dont_write_bytecode = True
import cloud_test


EXPECTED_CHECKS = {'ReadVoxels metadata': 1,
 'empty air': 1,
 'flat coarse ground offset 0': 1,
 'flat API offset 0': 1,
 'penetration offset 0 depth 0.05': 1,
 'penetration offset 0 depth 0.2': 1,
 'penetration offset 0 depth 0.5': 1,
 'flat coarse ground offset 0.5': 1,
 'flat API offset 0.5': 1,
 'penetration offset 0.5 depth 0.05': 1,
 'penetration offset 0.5 depth 0.2': 1,
 'penetration offset 0.5 depth 0.5': 1,
 'flat coarse ground offset 1.5': 1,
 'flat API offset 1.5': 1,
 'penetration offset 1.5 depth 0.05': 1,
 'penetration offset 1.5 depth 0.2': 1,
 'penetration offset 1.5 depth 0.5': 1,
 'flat coarse ground offset 3.5': 1,
 'flat API offset 3.5': 1,
 'penetration offset 3.5 depth 0.05': 1,
 'penetration offset 3.5 depth 0.2': 1,
 'penetration offset 3.5 depth 0.5': 1,
 'sloping terrain with body clearance': 1,
 'tilted root above slope': 1,
 'air above terrain (no dynamics claim)': 1,
 'water ignored': 1,
 'fully embedded terrain': 1,
 'shallow 0.2stud penetration': 1,
 'penetration API': 1,
 'high overhang clear seed': 1,
 'low overhang no clear seed (conservative)': 1,
 'low overhang API': 1,
 'initial part overlap': 1,
 'noncollidable part ignored': 1,
 'collision-group part exclusion': 1,
 'collision-group part restored': 1,
 'collision-group terrain exclusion': 1,
 'near wall not initial overlap': 1,
 'moving blocker now overlaps': 1,
 '100 spatial queries (not lease lifetimes)': 1,
 'terrain restored and verified': 1,
 'parts cleaned': 1,
 'collision group cleaned': 2}


def evidence_passed(task):
    """Accept only the complete matrix, including independent verified cleanup, not HTTP200."""
    if not isinstance(task, dict) or task.get("state") != "COMPLETE" or task.get("error"):
        return False
    output = task.get("output", {})
    values = output.get("results", []) if isinstance(output, dict) else []
    if not isinstance(values, list) or len(values) != 1 or not isinstance(values[0], dict):
        return False
    report = values[0]
    rows = report.get("results", [])
    if (report.get("kind") != "WindStep spatial only" or report.get("dynamicsAccepted") is not False
            or report.get("isServer") is not True or not isinstance(rows, list)
            or not all(isinstance(row, dict) and isinstance(row.get("name"), str)
                       and row.get("ok") is True for row in rows)):
        return False
    return (type(report.get("failed")) is int and report["failed"] == 0
            and type(report.get("passed")) is int and report["passed"] == len(rows)
            and Counter(row["name"] for row in rows) == EXPECTED_CHECKS)


def run(version, output_path):
    branch = subprocess.check_output(["git", "branch", "--show-current"], text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
    if branch != "main" or dirty:
        raise RuntimeError("Saved-engine probes require clean main after merge.sh")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    script = Path("tests/cloud/wind_step_spatial.luau").read_text()
    evidence = {"commit": commit, "probe_sha256": hashlib.sha256(script.encode()).hexdigest(),
                "saved_version": version, "published": False}

    def persist():
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(json.dumps(evidence, indent=2) + "\n")

    if version is None:
        gate = subprocess.run(["bash", "scripts/check.sh"], capture_output=True, text=True)
        evidence["check"] = gate.stdout
        persist()
        if gate.returncode or "CHECK: PASS" not in gate.stdout:
            raise RuntimeError("Local check failed; refusing Saved upload")
        data = Path("build/Robby.rbxl").read_bytes()
        evidence["build_sha256"] = hashlib.sha256(data).hexdigest()
        status, result = cloud_test.call("POST", f"/universes/v1/{cloud_test.U}/places/{cloud_test.P}/versions?versionType=Saved",
                                        data, "application/octet-stream",
                                        "Robby Wind Step probe: upload Saved version only, never publish", timeout=600)
        evidence["upload"] = {"status": status, "result": result}
        persist()
        if status != 200:
            raise RuntimeError(f"Saved upload failed: {status} {result}")
        version = result["versionNumber"]
        evidence["saved_version"] = version
    status, task = cloud_test.call("POST", f"/cloud/v2/universes/{cloud_test.U}/places/{cloud_test.P}/versions/{version}/luau-execution-session-tasks",
                                  json.dumps({"script": script, "timeout": "120s"}).encode(),
                                  desc="Run bounded Wind Step spatial query tests on the Saved version")
    evidence["creation"] = {"status": status, "task": task}
    persist()
    if status != 200 or not isinstance(task, dict) or not task.get("path"):
        raise RuntimeError(f"Probe creation failed: {status} {task}")
    path = "/cloud/v2/" + task["path"]
    for _ in range(60):
        time.sleep(3)
        status, task = cloud_test.call("GET", path, desc="Poll Wind Step spatial test")
        evidence["poll_status"], evidence["task"] = status, task
        persist()
        if status != 200 or not isinstance(task, dict):
            raise RuntimeError(f"Probe poll failed: {status} {task}")
        if task.get("state") in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    status, logs = cloud_test.call("GET", path + "/logs", desc="Read Wind Step spatial test diagnostics")
    evidence["logs"] = {"status": status, "result": logs}
    evidence["spatial_passed"] = evidence_passed(task)
    persist()
    print(f"SAVED VERSION: {version}; state={task.get('state')}; spatial_passed={evidence['spatial_passed']}")
    print(f"Evidence: {output_path}; dynamics NOT accepted; nothing published")
    return evidence["spatial_passed"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", type=int)
    parser.add_argument("--output", default="build/wind-step-probe.json")
    args = parser.parse_args()
    return 0 if run(args.version, args.output) else 1


if __name__ == "__main__":
    raise SystemExit(main())
