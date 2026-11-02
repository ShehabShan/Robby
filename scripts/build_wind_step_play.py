"""T-051a: build the Wind Step PLAY-mode place (TEST target only); no API calls, never uploads.
Usage: python3 scripts/build_wind_step_play.py [--target path/to/target.json]
Without --target the place is unbound and the server script refuses to run outside Studio.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_target import load_config  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FILES = ("src/server/WindStepDriver.luau", "src/server/WindStepClearance.luau", "src/shared/WindStep.luau",
         "src/shared/WindStepPlay.luau", "tests/play/wind_step_play.server.luau",
         "tests/play/wind_step_play.client.luau", "wind-step-play.project.json", "scripts/build_wind_step_play.py")


def build(target=None):
    project = json.loads((ROOT / "wind-step-play.project.json").read_text())
    tree = project["tree"]
    if "WindStepTest" in tree.get("ServerScriptService", {}) or "WindStepOwner" in json.dumps(tree):
        raise ValueError("play build must not contain the automated harness or owner test panel")
    attrs = tree["ServerScriptService"]["WindStepPlay"]["$attributes"]
    attrs["TestUniverseId"] = int(target["universeId"]) if target else 0
    attrs["TestPlaceId"] = int(target["placeId"]) if target else 0
    attrs["SourceRevision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
    attrs["SourceHashes"] = json.dumps(hashes, sort_keys=True)

    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)
    absolute(project)
    directory = ROOT / "build/play-test"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "play.project.json"
    path.write_text(json.dumps(project, indent=2) + "\n")
    place = directory / "WindStepPlay.rbxl"
    subprocess.run(["rojo", "build", str(path), "-o", str(place)], cwd=ROOT, check=True)
    manifest = {"schema": 1, "kind": "WindStep play-mode TEST place", "target": target,
                "sourceRevision": attrs["SourceRevision"], "sourceHashes": hashes,
                "placeSha256": hashlib.sha256(place.read_bytes()).hexdigest(),
                "remaining": ["exact-byte owner approval", "one-shot TEST publish (T-051a2)", "owner feel report"]}
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PLAY place built; " + ("target bound" if target else "target unbound (Studio only)"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target")
    args = parser.parse_args()
    build(load_config(args.target) if args.target else None)
