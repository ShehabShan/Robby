"""Build a DISABLED published-test candidate; no API calls and no upload mode.
Optional --target binds explicit separate IDs. Omit to build unconfigured refusal fixture.
T-044b2b interactive start/report and T-044b3 intake/release are still required.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from test_target import load_config

ROOT = Path(__file__).resolve().parents[1]
HEADER = "tests/published/wind_step_header.luau"
POLICY = "tests/published/WindStepPublishedPolicy.luau"
STUDIO = "tests/studio/wind_step.server.luau"
FILES = ("src/server/WindStepDriver.luau", "src/server/WindStepClearance.luau", "src/shared/WindStep.luau",
         STUDIO, "tests/studio/WindStepEvidence.luau", HEADER, POLICY, "scripts/build_wind_step_published.py",
         "scripts/test_target.py", "wind-step-test.project.json")


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError("Studio harness changed; review published adapter before rebuilding")
    return source.replace(before, after, 1)


def generated_source(studio, header):
    marker = "local player = Players:GetPlayers()[1]\n"
    if studio.count(marker) != 1:
        raise ValueError("Studio entry boundary drift")
    body = marker + studio.split(marker)[1]
    body = replace_once(body, "Evidence.finish(environment, rows, cleanup)",
                        "Policy.finish(target, environment, rows, cleanup, Evidence)")
    body = replace_once(body, 'assert(#Players:GetPlayers() == 1 and player.Character == character and humanoid.Health > 0, "player changed")',
                        'assert(\n\t\t#Players:GetPlayers() == 1 and Players:GetPlayers()[1] == player\n\t\t\tand player.UserId == target.ownerUserId and player.Character == character\n\t\t\tand humanoid.Health > 0 and game.GameId == target.universeId\n\t\t\tand game.PlaceId == target.placeId,\n\t\t"player or destination changed"\n\t)')
    return header.rstrip() + "\n" + body


def build(target=None):
    if target is not None:
        from test_target import validate_config
        validate_config(target)
    project = json.loads((ROOT / "wind-step-test.project.json").read_text())
    project["name"] = "Robby published test candidate - DISABLED NOT RELEASE READY"
    node = project["tree"]["ServerScriptService"]["WindStepTest"]
    attrs = node["$attributes"]
    attrs.update({"TestUniverseId": int(target["universeId"]) if target else 0,
                  "TestPlaceId": int(target["placeId"]) if target else 0,
                  "TestOwnerUserId": int(target["ownerUserId"]) if target else 0,
                  "RunWindStep": False})
    node["$properties"]["Disabled"] = True
    node["PublishedPolicy"] = {"$path": POLICY}
    source = generated_source((ROOT / STUDIO).read_text(), (ROOT / HEADER).read_text())
    directory = ROOT / "build/published-test"
    directory.mkdir(parents=True, exist_ok=True)
    script = directory / "wind_step.server.luau"
    script.write_text(source)
    subprocess.run(["stylua", str(script)], check=True, cwd=ROOT)
    source = script.read_bytes()
    node["$path"] = str(script)
    attrs["SourceRevision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
    attrs["SourceHashes"] = json.dumps(hashes, sort_keys=True)
    attrs["GeneratedServerSha256"] = hashlib.sha256(source).hexdigest()

    def absolute(tree):
        if isinstance(tree, dict):
            for key, value in tree.items():
                if key == "$path":
                    tree[key] = str(ROOT / value)
                else:
                    absolute(value)
    absolute(project)
    path = directory / "candidate.project.json"
    path.write_text(json.dumps(project, indent=2) + "\n")
    # Rojo paths are relative to the project; luau-lsp resolves them against repo root.
    mapping = json.loads(subprocess.check_output(["rojo", "sourcemap", str(path)], cwd=ROOT, text=True))
    def rebase_paths(node):
        if "filePaths" in node:
            node["filePaths"] = [str((directory / p).resolve().relative_to(ROOT)) for p in node["filePaths"]]
        for child in node.get("children", []):
            rebase_paths(child)
    rebase_paths(mapping)
    (directory / "sourcemap.json").write_text(json.dumps(mapping))
    place = directory / "WindStepPublishedCandidate.rbxl"
    subprocess.run(["rojo", "build", str(path), "-o", str(place)], cwd=ROOT, check=True)
    manifest = {"schema": 1, "kind": "WindStep disabled published candidate", "publishReady": False,
                "dynamicsAccepted": False, "target": target, "sourceRevision": attrs["SourceRevision"],
                "sourceHashes": hashes, "generatedServerSha256": attrs["GeneratedServerSha256"],
                "placeSha256": hashlib.sha256(place.read_bytes()).hexdigest(),
                "remaining": ["owner start/status/report UI and lifecycle", "published evidence intake and release checks",
                              "configured private destination permissions", "actual player dynamics evidence"]}
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("DISABLED candidate built; NOT publish-ready; " + ("target bound" if target else "target unconfigured"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target")
    args = parser.parse_args()
    build(load_config(args.target) if args.target else None)
