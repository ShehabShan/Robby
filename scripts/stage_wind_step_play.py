"""T-051a2 OFFLINE staging for the Wind Step PLAY build. No HTTP, no upload, no approval.

--stage --target TARGET --enable-local-test builds exact TEST-bound play bytes.
--verify --manifest MANIFEST --manifest-sha256 PIN --place PLACE re-checks them against a
retained manifest digest and a fresh rebuild. Same interface as stage_wind_step_published.py
so the existing consent/one-shot transaction can bind it (wiring is a separate reviewed step).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_wind_step_play as candidate  # noqa: E402
from ingest_wind_step_published import load, MAX_MANIFEST, MAX_PLACE, digest, require  # noqa: E402
from test_target import load_config, validate_config  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
KIND = "WindStep locally staged play-mode test"
TOOLING = ("scripts/stage_wind_step_play.py", "scripts/stage_wind_step_play_package.luau",
           "scripts/build_wind_step_play.py")
REMAINING = ["fresh main-only destination/consent/write gates and publication transaction",
             "owner hand-play feel report"]
FIELDS = {"schema", "kind", "publishReady", "target", "sourceRevision", "sourceHashes", "toolingHashes",
          "placeSha256", "remaining"}
DIRECTORY = ROOT / "build/play-stage"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def tooling_hashes():
    return {p: sha((ROOT / p).read_bytes()) for p in TOOLING}


def bounded_place(path):
    with Path(path).open("rb") as stream:
        data = stream.read(MAX_PLACE + 1)
    require(0 < len(data) <= MAX_PLACE, "bad staged place size")
    return data


def fresh_candidate(target):
    validate_config(target)  # BEFORE invoking any build tool
    candidate.build(target)
    directory = ROOT / "build/play-test"
    manifest, _ = load(directory / "manifest.json", MAX_MANIFEST)
    require(manifest["target"] == target, "play build target mismatch")
    return manifest, directory / "WindStepPlay.rbxl"


def package(mode, expected, path, revision):
    require(type(revision) is str and re.fullmatch(r"[a-f0-9]{40}", revision), "bad source revision")
    subprocess.run(["lune", "run", str(ROOT / TOOLING[1]), mode, str(expected), str(path), revision],
                   cwd=ROOT, check=True, capture_output=True, timeout=30)


def stage(target, *, enable_local_test=False):
    require(enable_local_test is True, "explicit local enablement required; NOT permission to publish")
    validate_config(target)
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    place_path, manifest_path = DIRECTORY / "WindStepPlayStage.rbxl", DIRECTORY / "manifest.json"
    place_path.unlink(missing_ok=True)
    manifest_path.unlink(missing_ok=True)
    manifest, expected = fresh_candidate(target)
    with tempfile.TemporaryDirectory(prefix="wind-play-stage-") as directory:
        staged = Path(directory) / "stage.rbxl"
        package("stage", expected, staged, manifest["sourceRevision"])
        place = bounded_place(staged)
        package("verify", expected, staged, manifest["sourceRevision"])
        result = {k: manifest[k] for k in ("target", "sourceRevision", "sourceHashes")}
        result.update(schema=1, kind=KIND, publishReady=False, toolingHashes=tooling_hashes(),
                      placeSha256=sha(place), remaining=REMAINING)
        raw = (json.dumps(result, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()
        require(len(raw) <= MAX_MANIFEST, "manifest too large")
        place_path.write_bytes(place)
        manifest_path.write_bytes(raw)  # manifest last: a partial output cannot verify
    return {"status": "LOCAL_PLAY_STAGE_ONLY", "manifest": str(manifest_path), "manifestSha256": sha(raw),
            "place": str(place_path), "placeSha256": sha(place), "publishReady": False}


def verify(manifest_path, manifest_sha256, place_path):
    digest(manifest_sha256, "independently retained manifest digest")
    manifest, raw = load(manifest_path, MAX_MANIFEST)
    require(sha(raw) == manifest_sha256, "pinned manifest mismatch")
    require(type(manifest) is dict and set(manifest) == FIELDS, "unexpected staged manifest fields")
    require(type(manifest["schema"]) is int and manifest["schema"] == 1 and manifest["kind"] == KIND,
            "bad staged manifest schema/kind")
    require(manifest["publishReady"] is False, "local staging cannot claim publishReady")
    require(manifest["remaining"] == REMAINING, "staging gates changed")
    validate_config(manifest["target"])
    revision = manifest["sourceRevision"]
    require(type(revision) is str and re.fullmatch(r"[a-f0-9]{40}", revision), "bad source revision")
    require(manifest["toolingHashes"] == tooling_hashes(), "staging tooling differs")
    digest(manifest["placeSha256"], "staged place hash")
    place = bounded_place(place_path)
    require(sha(place) == manifest["placeSha256"], "staged place digest mismatch")
    expected_manifest, expected = fresh_candidate(manifest["target"])
    require(manifest["sourceHashes"] == expected_manifest["sourceHashes"], "staged sources differ from local source")
    with tempfile.TemporaryDirectory(prefix="wind-play-verify-") as directory:
        snapshot = Path(directory) / "stage.rbxl"
        snapshot.write_bytes(place)
        package("verify", expected, snapshot, revision)
    return {"status": "LOCAL_PLAY_STAGE_VERIFIED_ONLY", "manifestSha256": sha(raw), "placeSha256": sha(place),
            "publishReady": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--stage", action="store_true")
    mode.add_argument("--verify", action="store_true")
    parser.add_argument("--target")
    parser.add_argument("--enable-local-test", action="store_true")
    parser.add_argument("--manifest")
    parser.add_argument("--manifest-sha256")
    parser.add_argument("--place")
    args = parser.parse_args()
    try:
        if args.stage:
            require(args.target and not any((args.manifest, args.manifest_sha256, args.place)), "stage arguments required")
            result = stage(load_config(args.target), enable_local_test=args.enable_local_test)
        else:
            require(all((args.manifest, args.manifest_sha256, args.place)) and not args.target
                    and not args.enable_local_test, "verify arguments required")
            result = verify(args.manifest, args.manifest_sha256, args.place)
        print(json.dumps(result, sort_keys=True))
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        parser.exit(2, "PLAY STAGING REFUSED: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
