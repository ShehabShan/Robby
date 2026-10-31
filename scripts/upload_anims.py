# /// script
# dependencies = ["httpx"]
# ///
"""T-026c: upload KeyframeSequence .rbxm files as Animation assets under the owner (Open Cloud Assets API).
Usage: uv run scripts/upload_anims.py build/anims/R15_WalkTrack.rbxm [...]
Prints NAME=assetId lines. Needs the `roblox-open-cloud` PromptQL integration."""
import json, os, sys, time, pathlib, httpx

OWNER = "7738981129"  # universe 10773761715 owner (users/7738981129)
B = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com"
H = {"Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"]}


def upload(path: pathlib.Path, c: httpx.Client) -> str:
    name = "Robby " + path.stem.replace("R15_", "").replace("Track", "")
    req = {"assetType": "Animation", "displayName": name,
           "description": "Robby movement animation (R15 movement kit, T-026c)",
           "creationContext": {"creator": {"userId": OWNER}}}
    r = c.post(B + "/assets/v1/assets",
               headers={**H, "X-PromptQL-Description": f"Robby T-026c: upload animation {name}"},
               files={"request": (None, json.dumps(req), "application/json"),
                      "fileContent": (path.name, path.read_bytes(), "model/x-rbxm")})
    if r.status_code >= 300:
        raise SystemExit(f"FAIL {path.name}: HTTP {r.status_code} {r.text[:400]}")
    op = r.json()
    for _ in range(30):
        if op.get("done"):
            break
        time.sleep(2)
        op = c.get(B + "/assets/v1/" + op["path"],
                   headers={**H, "X-PromptQL-Description": f"Robby T-026c: check upload {name}"}).json()
    if not op.get("done"):
        raise SystemExit(f"FAIL {path.name}: not done {json.dumps(op)[:300]}")
    if "error" in op:
        raise SystemExit(f"FAIL {path.name}: {json.dumps(op['error'])[:300]}")
    return op["response"]["assetId"]


with httpx.Client(timeout=120) as c:
    for p in sys.argv[1:]:
        print(f"{pathlib.Path(p).stem}={upload(pathlib.Path(p), c)}", flush=True)