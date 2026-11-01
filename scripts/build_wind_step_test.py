"""Build disabled isolated Studio place with exact production source hashes; never uploads."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ("src/server/WindStepDriver.luau", "src/server/WindStepClearance.luau",
         "src/shared/WindStep.luau", "tests/studio/wind_step.server.luau", "tests/studio/WindStepEvidence.luau")


def build():
    project = json.loads((ROOT / "wind-step-test.project.json").read_text())
    attrs = project["tree"]["ServerScriptService"]["WindStepTest"]["$attributes"]
    attrs["SourceRevision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    attrs["SourceHashes"] = json.dumps({p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}, sort_keys=True)

    def absolutize(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolutize(value)
    absolutize(project)
    (ROOT / "build").mkdir(exist_ok=True)
    path = ROOT / "build/wind-step.generated.project.json"
    path.write_text(json.dumps(project))
    subprocess.run(["rojo", "build", str(path), "-o", str(ROOT / "build/WindStepTest.rbxl")], cwd=ROOT, check=True)
    manifest = {
        "schema": 1, "kind": "WindStep disabled Studio bundle",
        "sourceRevision": attrs["SourceRevision"],
        "sourceHashes": json.loads(attrs["SourceHashes"]),
        "placeSha256": hashlib.sha256((ROOT / "build/WindStepTest.rbxl").read_bytes()).hexdigest(),
    }
    (ROOT / "build/WindStepTest.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Reproducible archive metadata; never include the live game or unrelated sources.
    members = {
        "WindStepTest.rbxl": (ROOT / "build/WindStepTest.rbxl").read_bytes(),
        "WindStepTest.manifest.json": (ROOT / "build/WindStepTest.manifest.json").read_bytes(),
        "README.txt": (ROOT / "tests/studio/WIND_STEP_README.txt").read_bytes(),
    }
    with zipfile.ZipFile(ROOT / "build/WindStepTest.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in members.items():
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, content)
    print("Disabled isolated place built; source revision " + attrs["SourceRevision"])


if __name__ == "__main__":
    build()
