"""Bounded OFFLINE candidate consistency review; never authorizes release or dynamics.
The disabled candidate is not a delivered playable release. T-044b3b must add
receipt/version binding before this tooling may classify actual published evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

import build_wind_step_published as builder
import ingest_wind_step_evidence as common
from test_target import validate_config

ROOT = Path(__file__).resolve().parents[1]
MAX_REPORT = 524288
MAX_MANIFEST = 65536
MAX_PLACE = 32 * 1024 * 1024
require = common.require


def load(path, limit):
    with Path(path).open("rb") as stream:
        data = stream.read(limit + 1)
    require(len(data) <= limit, "input exceeds byte limit")
    return common.strict_json(data.decode("utf-8")), data


def digest(value, label):
    require(type(value) is str and re.fullmatch(r"[a-f0-9]{64}", value), "bad " + label)


def validate_manifest(manifest, place):
    require(type(manifest) is dict and type(manifest.get("schema")) is int and manifest["schema"] == 1,
            "bad manifest schema")
    require(manifest.get("kind") == "WindStep disabled published candidate", "unsupported manifest kind")
    require(manifest.get("publishReady") is False and manifest.get("dynamicsAccepted") is False,
            "candidate cannot claim release/dynamics readiness")
    target = manifest.get("target")
    validate_config(target)
    require(type(manifest.get("sourceRevision")) is str and
            re.fullmatch(r"[a-f0-9]{40}", manifest["sourceRevision"]), "bad source revision")
    hashes = manifest.get("sourceHashes")
    require(type(hashes) is dict and set(hashes) == set(builder.FILES), "incomplete/extraneous sources")
    for path in builder.FILES:
        digest(hashes[path], "source hash")
        require(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == hashes[path],
                "local source differs: " + path)
    digest(manifest.get("generatedServerSha256"), "generated server hash")
    with tempfile.TemporaryDirectory(prefix="published-source-") as directory:
        generated = Path(directory) / "server.luau"
        generated.write_text(builder.generated_source((ROOT / builder.STUDIO).read_text(),
                                                      (ROOT / builder.HEADER).read_text()))
        subprocess.run(["stylua", str(generated)], cwd=ROOT, check=True, capture_output=True, timeout=30)
        require(hashlib.sha256(generated.read_bytes()).hexdigest() == manifest["generatedServerSha256"],
                "generated server differs")
    digest(manifest.get("placeSha256"), "place hash")
    require(type(place) is bytes and 0 < len(place) <= MAX_PLACE, "bad place size")
    require(hashlib.sha256(place).hexdigest() == manifest["placeSha256"], "place digest mismatch")
    return {k: int(target[k]) for k in ("universeId", "placeId", "ownerUserId")}


def calculate(report):
    with tempfile.TemporaryDirectory(prefix="published-evidence-") as directory:
        path = Path(directory) / "report.json"
        path.write_text(json.dumps(report, allow_nan=False))
        result = subprocess.run(["lune", "run", "scripts/wind_step_published_evidence.luau", str(path)],
                                cwd=ROOT, check=True, capture_output=True, text=True, timeout=30)
    return common.strict_json(result.stdout)


def review(report, manifest, place):
    # Programmatic callers receive the same size/nonfinite limits as the CLI.
    require(len(json.dumps(report, allow_nan=False).encode()) <= MAX_REPORT, "report exceeds byte limit")
    require(len(json.dumps(manifest, allow_nan=False).encode()) <= MAX_MANIFEST, "manifest exceeds byte limit")
    target = validate_manifest(manifest, place)
    result = review_report(report, manifest, target)
    return dict(result, status="OFFLINE_CANDIDATE_REVIEW", releaseEvidenceAccepted=False,
                warning="Disabled candidate only; not a delivered release. Hash consistency is not signed attestation. "
                        "No proof of Roblox execution, release version, physics acceptance or permission to activate.")


def review_report(report, manifest, target):
    """Shared bounded report/policy checks; callers must validate their artifact route."""
    require(len(json.dumps(report, allow_nan=False).encode()) <= MAX_REPORT, "report exceeds byte limit")
    require(type(report) is dict and report.get("kind") == "WindStep isolated published dynamics", "bad report kind")
    missing = common.validate_common_report(report, manifest)
    require(type(report.get("target")) is dict and set(report["target"]) == set(target), "bad report target")
    for key, value in target.items():
        require(type(report["target"][key]) is int and report["target"][key] == value, "report target mismatch")
    env = report["environment"]
    for key, value in (("universeId", target["universeId"]), ("placeId", target["placeId"]),
                       ("playerUserId", target["ownerUserId"])):
        require(type(env.get(key)) is int and env[key] == value, "environment target mismatch")
    require(type(env.get("jobId")) is str and 0 < len(env["jobId"].encode()) <= 128, "bad job ID")
    require(0 < env["placeVersion"] <= 9007199254740991, "bad published place version")
    require(env.get("generatedServerSha256") == manifest["generatedServerSha256"], "report generated hash mismatch")
    computed = calculate(report)
    for key in ("passed", "expected"):
        require(type(report.get(key)) is int and report[key] == computed[key], "claimed " + key + " differs from policy")
    require(report["matrixPassed"] == computed["matrixPassed"], "claimed matrixPassed differs from policy")
    require(report.get("remaining") == computed["remaining"], "missing/changed outstanding gates")
    require(computed["dynamicsAccepted"] is False, "policy unexpectedly accepted dynamics")
    return {"status": "OFFLINE_CANDIDATE_REVIEW", "releaseEvidenceAccepted": False, "dynamicsAccepted": False,
            "firstSliceReportedPass": computed["matrixPassed"], "passed": computed["passed"],
            "expected": computed["expected"], "missing": missing, "failed": computed["failed"],
            "remaining": computed["remaining"], "sourceRevision": manifest["sourceRevision"],
            "target": target, "reportedPlaceVersion": env["placeVersion"], "error": report.get("error"),
            "warning": "Disabled candidate only; not a delivered release. Hash consistency is not signed attestation. "
                       "No proof of Roblox execution, release version, physics acceptance or permission to activate."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--manifest-sha256", required=True, help="Independently retained exact manifest digest")
    parser.add_argument("--place", required=True, type=Path, help="Exact candidate place bytes paired with manifest")
    parser.add_argument("--candidate-review", action="store_true", help="Explicit offline-only review; never live evidence")
    args = parser.parse_args()
    try:
        require(args.candidate_review, "No delivered release intake yet; only explicit --candidate-review is supported")
        report, _ = load(args.report, MAX_REPORT)
        manifest, raw_manifest = load(args.manifest, MAX_MANIFEST)
        digest(args.manifest_sha256, "pinned manifest hash")
        require(hashlib.sha256(raw_manifest).hexdigest() == args.manifest_sha256, "pinned manifest differs")
        with args.place.open("rb") as stream:
            place = stream.read(MAX_PLACE + 1)
        result = review(report, manifest, place)
    except (ValueError, OSError, RecursionError, OverflowError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "INVALID_OR_UNVERIFIABLE", "dynamicsAccepted": False,
                          "releaseEvidenceAccepted": False, "error": str(error)}))
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result["firstSliceReportedPass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
