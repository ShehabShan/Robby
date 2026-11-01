"""Build disabled isolated Studio place with exact production source hashes; never uploads."""
import hashlib
import json
from pathlib import Path
import subprocess

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
    print("Disabled isolated place built; source revision " + attrs["SourceRevision"])


if __name__ == "__main__":
    build()
