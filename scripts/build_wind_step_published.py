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
         "scripts/test_target.py", "wind-step-test.project.json", "src/shared/OwnerTestSession.luau",
         "tests/published/OwnerTestAdapter.luau", "tests/published/OwnerTestTransport.luau",
         "tests/published/wind_step_footer.luau")


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
    # Reviewed cancellation seams only; the canonical case matrix and driver stay exact.
    body = replace_once(body, marker, "local player = current[1]\n")
    body = replace_once(body, 'local fixtures = Instance.new("Folder")\nfixtures.Name = "WindStepFixtures"\nfixtures.Parent = workspace', 'local fixtures: any = nil')
    body = replace_once(body, 'local function part(name, size, position)', 'local cancelled = false\ncancelActive = function()\n\tcancelled = true\n\tif lease then\n\t\tlease.stop(true)\n\tend\nend\nlocal function checkpoint()\n\tcheck()\n\tassert(not cancelled, "worker cancelled")\n\tif character then\n\t\tassert(player.Character == character and humanoid.Health > 0 and root:IsDescendantOf(workspace), "original character lost")\n\tend\nend\nlocal function part(name, size, position)')
    body = replace_once(body, '\t\ttask.wait()\n', '\t\tcheckpoint()\n\t\ttask.wait()\n\t\tcheckpoint()\n')
    body = replace_once(body, '\tRunService.PostSimulation:Wait()', '\tlocal aligned = false\n\ttable.insert(connections, RunService.PostSimulation:Connect(function()\n\t\taligned = true\n\tend))\n\twaitUntil(function() return aligned end, 1)\n\tdisconnect()\n\tcheckpoint()')
    body = replace_once(body, 'local function runCase(name: string, kind: string, mode: string)', 'local function runCase(name: string, kind: string, mode: string)\n\tcheckpoint()')
    body = replace_once(body, 'local success, err = pcall(callback, ...)', 'local success, err = pcall(function(...)\n\t\t\t\tcheckpoint()\n\t\t\t\treturn callback(...)\n\t\t\tend, ...)')
    body = replace_once(body, '\t\t\t\tif lease then\n\t\t\t\t\tlease.stop()\n\t\t\t\tend', '\t\t\t\tcancelActive()')
    body = replace_once(body, '\tlease = Driver.prepare(player, Motion.PROPOSED, Vector3.xAxis)', '\tcheckpoint()\n\tlease = Driver.prepare(player, Motion.PROPOSED, Vector3.xAxis)\n\tcheckpoint()')
    body = replace_once(body, '\trow.committed = lease.commit(workspace:GetServerTimeNow())', '\tcheckpoint()\n\trow.committed = lease.commit(workspace:GetServerTimeNow())\n\tcheckpoint()')
    body = replace_once(body, '\tassert(Evidence.accept(row), "case failed: " .. name)', '\tcheckpoint()\n\tassert(Evidence.accept(row), "case failed: " .. name)\n\tprogress(#rows)')
    body = replace_once(body, 'local ok, failure = xpcall(function()', 'local ok, failure = xpcall(function()\n\tcheckpoint()\n\tfixtures = Instance.new("Folder")\n\tfixtures.Name = "WindStepFixtures"\n\tfixtures.Parent = workspace')
    body = replace_once(body, '\t\tlease.stop()\n\tend\nend)', '\t\tlease.stop(true)\n\tend\nend)')
    body = replace_once(body, '\tfixtures:Destroy()', '\tif fixtures then fixtures:Destroy() end')
    body = replace_once(body, 'assert(fixtures.Parent == nil and #connections == 0', 'assert((fixtures == nil or fixtures.Parent == nil) and #connections == 0')
    # Return only after every independent cleanup attempt; transport owns encoding/export.
    end_marker = 'local result = Instance.new("StringValue")'
    if body.count(end_marker) != 1:
        raise ValueError("Studio report boundary drift")
    body = body.split(end_marker)[0] + "return report, ok, cleanup\n"
    footer = (ROOT / "tests/published/wind_step_footer.luau").read_text()
    return header.rstrip() + "\nlocal cancelActive: () -> () = function() end\nlocal function runWorker(check: () -> (), progress: (number) -> ())\n" + body + "end\n" + footer


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
    for name, path in {"OwnerTestSession": "src/shared/OwnerTestSession.luau",
                       "OwnerTestAdapter": "tests/published/OwnerTestAdapter.luau",
                       "OwnerTestTransport": "tests/published/OwnerTestTransport.luau"}.items():
        node[name] = {"$path": path}
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
