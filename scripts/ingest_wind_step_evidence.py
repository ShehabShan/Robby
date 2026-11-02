"""Offline review of an owner-returned report. Self-reported evidence is NOT attestation."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MAX_BYTES = 2_000_000
FILES = ("src/server/WindStepDriver.luau", "src/server/WindStepClearance.luau",
         "src/shared/WindStep.luau", "tests/studio/wind_step.server.luau", "tests/studio/WindStepEvidence.luau")
KINDS = {**{f"travel-{mode}": "travel" for mode in ("auto", "player", "server")},
         "wall": "wall", "fall": "fall", "cancel": "cancel",
         **{f"lifetime-{i}": "travel" for i in range(1, 101)}}
METRICS = ("distance", "maxX", "elapsed", "minDt", "maxDt", "pairs", "maxYError", "maxYDip",
           "maxSide", "commandedDistance", "lastSpeed", "simulatedSeconds")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"nonfinite JSON value: {value}")


def strict_json(text):
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def load(path):
    with Path(path).open("rb") as stream:
        data = stream.read(MAX_BYTES + 1)
    require(len(data) <= MAX_BYTES, "input exceeds 2MB limit")
    return strict_json(data.decode("utf-8-sig"))


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def boolean_fields(value, fields):
    for key in fields:
        require(type(value.get(key)) is bool, f"{key} must be boolean")


def validate_manifest(manifest):
    require(type(manifest) is dict and type(manifest.get("schema")) is int and manifest["schema"] == 1, "bad manifest schema")
    require(manifest.get("kind") == "WindStep disabled Studio bundle", "bad manifest kind")
    require(re.fullmatch(r"[a-f0-9]{40}", str(manifest.get("sourceRevision", ""))), "bad source revision")
    hashes = manifest.get("sourceHashes")
    require(type(hashes) is dict and set(hashes) == set(FILES), "incomplete manifest sources")
    for path, digest in hashes.items():
        require(re.fullmatch(r"[a-f0-9]{64}", str(digest)), f"bad digest: {path}")
        require(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest,
                f"local source differs from tested bundle: {path}; review with matching checkout")
    require(re.fullmatch(r"[a-f0-9]{64}", str(manifest.get("placeSha256", ""))), "bad place digest")


def validate_report(report, manifest):
    require(type(report) is dict and report.get("kind") == "WindStep isolated Studio dynamics", "bad report kind")
    return validate_common_report(report, manifest)


def validate_common_report(report, manifest):
    """Shared structural/sample checks only; each entry point enforces its own scope."""
    require(type(report) is dict and type(report.get("schema")) is int and report["schema"] == 1, "bad report schema")
    boolean_fields(report, ("cleanup", "matrixPassed", "dynamicsAccepted", "runCompleted"))
    require(report["dynamicsAccepted"] is False, "premature dynamics acceptance")
    require(report.get("error") is None or isinstance(report["error"], str), "invalid error")
    require(not report["runCompleted"] or report.get("error") is None, "completed run has error")
    env = report.get("environment")
    require(type(env) is dict, "missing environment")
    boolean_fields(env, ("studio", "running", "server", "optIn"))
    require(type(env.get("players")) is int and 0 <= env["players"] <= 100, "bad player count")
    require(isinstance(env.get("engine"), str) and 0 < len(env["engine"]) <= 200, "missing engine version")
    require(type(env.get("placeVersion")) is int and env["placeVersion"] >= 0, "bad place version")
    require(number(env.get("gravity")) and env["gravity"] > 0, "bad gravity")
    require(env.get("sourceRevision") == manifest["sourceRevision"], "source revision mismatch")
    require(isinstance(env.get("sourceHashes"), str), "missing encoded source hashes")
    require(strict_json(env["sourceHashes"]) == manifest["sourceHashes"], "source hash mismatch")
    rows = report.get("results")
    require(type(rows) is list and len(rows) <= 106, "bad result count")
    seen = set()
    for row in rows:
        require(type(row) is dict, "malformed case")
        name = row.get("name")
        require(isinstance(name, str) and name in KINDS and name not in seen, "unknown/duplicate case")
        seen.add(name)
        require(row.get("kind") == KINDS[name], f"wrong kind: {name}")
        boolean_fields(row, ("committed", "clean", "restored", "phaseOK", "cancelled", "velocityKept"))
        for key in METRICS:
            require(number(row.get(key)), f"nonfinite/missing metric: {name}.{key}")
        require(row["pairs"] >= 0 and row["pairs"] % 1 == 0, f"invalid pairs: {name}")
        samples = row.get("samples")
        require(type(samples) is list and len(samples) <= 128, f"invalid samples: {name}")
        if name.startswith("lifetime-"):
            require(not samples, "unexpected lifetime samples")
        else:
            # Failed/partial callbacks may leave fewer samples; canonical failure still retained.
            require(len(samples) <= row["pairs"], f"extra samples: {name}")
            if row["phaseOK"] and row["clean"] and row["committed"]:
                require(len(samples) == min(row["pairs"], 128), f"missing samples: {name}")
        for sample in samples:
            require(type(sample) is dict, "malformed sample")
            boolean_fields(sample, ("applied",))
            require(all(number(sample.get(k)) for k in ("dt", "t", "x", "y", "vy", "commandSpeed")), "bad sample metric")
        if samples and len(samples) == row["pairs"] and row["phaseOK"]:
            def close(a, b):
                return math.isclose(a, b, rel_tol=1e-7, abs_tol=1e-6)
            for actual, expected in (
                (row["simulatedSeconds"], sum(s["dt"] for s in samples)),
                (row["commandedDistance"], sum(s["dt"] * s["commandSpeed"] for s in samples)),
                (row["minDt"], min(s["dt"] for s in samples)),
                (row["maxDt"], max(s["dt"] for s in samples)),
                (row["distance"], samples[-1]["x"]),
                (row["maxX"], max(0, *(s["x"] for s in samples))),
                (row["lastSpeed"], samples[-1]["commandSpeed"]),
                (row["elapsed"], samples[-1]["t"]),
            ):
                require(close(actual, expected), f"sample/aggregate mismatch: {name}")
            require(all(s["applied"] and 0 < s["dt"] <= .05 and 0 <= s["commandSpeed"] <= 70.001 for s in samples),
                    f"invalid applied interval: {name}")
            require(all(a["t"] <= b["t"] for a, b in zip(samples, samples[1:])), f"unordered samples: {name}")
    return sorted(set(KINDS) - seen)


def review(report, manifest):
    validate_manifest(manifest)
    missing = validate_report(report, manifest)
    with tempfile.TemporaryDirectory(prefix="wind-evidence-") as directory:
        path = Path(directory) / "report.json"
        path.write_text(json.dumps(report, allow_nan=False))
        result = subprocess.run(["lune", "run", "scripts/wind_step_evidence.luau", str(path)],
                                cwd=ROOT, capture_output=True, text=True, timeout=30, check=True)
    computed = strict_json(result.stdout)
    for key in ("passed", "expected"):
        require(type(report.get(key)) is int and report[key] == computed[key], f"claimed {key} differs from policy")
    require(report["matrixPassed"] == computed["matrixPassed"], "claimed matrixPassed differs from policy")
    require(report.get("remaining") == computed["remaining"], "missing/changed outstanding gates")
    require(computed["dynamicsAccepted"] is False, "policy unexpectedly accepted dynamics")
    return {"status": "FIRST_SLICE_REPORTED_PASS" if computed["matrixPassed"] else "BLOCKED_OR_FAILED",
            "dynamicsAccepted": False, "passed": computed["passed"], "expected": computed["expected"],
            "missing": missing, "failed": computed["failed"], "remaining": computed["remaining"],
            "sourceRevision": manifest["sourceRevision"], "error": report.get("error"),
            "warning": "Offline consistency review of self-reported JSON, not proof of Roblox execution or permission to activate."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--manifest", required=True, type=Path, help="Manifest delivered with the exact tested bundle")
    args = parser.parse_args()
    try:
        result = review(load(args.report), load(args.manifest))
    except (ValueError, OSError, RecursionError, OverflowError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "INVALID_OR_UNVERIFIABLE", "dynamicsAccepted": False, "error": str(error)}))
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "FIRST_SLICE_REPORTED_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
