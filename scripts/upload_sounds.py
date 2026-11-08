# /// script
# dependencies = ["httpx"]
# ///
"""T-053a4b: upload OGG sounds as Audio assets under the owner (Open Cloud Assets API).
Usage: uv run scripts/upload_sounds.py [--dry-run] assets/sfx/<name>.ogg [...]
Prints NAME=assetId lines (or NAME=PENDING when moderation is not finished). Needs `roblox-open-cloud`."""
import json, os, sys, time, pathlib, httpx

OWNER = "7738981129"  # universe 10773761715 owner (users/7738981129)
if "PROMPTQL_PLATFORM_API_URL" in os.environ:
    B = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com"
    H = {"Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"]}
else:
    from cloud_test import _load_env_key
    B = "https://apis.roblox.com"
    H = {"x-api-key": _load_env_key() or ""}


def upload(path: pathlib.Path, c: httpx.Client) -> str:
    name = "Robby " + path.stem
    req = {"assetType": "Audio", "displayName": name,
           "description": "Robby Crescent Cut sound effect (T-053a4b)",
           "creationContext": {"creator": {"userId": OWNER}}}
    r = c.post(B + "/assets/v1/assets",
               headers={**H, "X-PromptQL-Description": f"Robby T-053a4b: upload sound {name}"},
               files={"request": (None, json.dumps(req), "application/json"),
                      "fileContent": (path.name, path.read_bytes(), "audio/ogg")})
    if r.status_code >= 300:
        raise SystemExit(f"FAIL {path.name}: HTTP {r.status_code} {r.text[:400]}")
    op = r.json()
    for _ in range(30):
        if op.get("done"):
            break
        time.sleep(2)
        op = c.get(B + "/assets/v1/" + op["path"],
                   headers={**H, "X-PromptQL-Description": f"Robby T-053a4b: check upload {name}"}).json()
    if "error" in op:
        raise SystemExit(f"FAIL {path.name}: {json.dumps(op['error'])[:300]}")
    if not op.get("done"):
        return "PENDING:" + op.get("path", "?")
    return op["response"]["assetId"]


args = [a for a in sys.argv[1:] if a != "--dry-run"]
if "--dry-run" in sys.argv:
    for p in args:
        q = pathlib.Path(p)
        print(f"DRY {q.stem}: {q.stat().st_size} bytes, would upload as Audio under user {OWNER}")
    sys.exit(0)
with httpx.Client(timeout=120) as c:
    for p in args:
        print(f"{pathlib.Path(p).stem}={upload(pathlib.Path(p), c)}", flush=True)
