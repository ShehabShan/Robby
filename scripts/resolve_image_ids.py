# /// script
# dependencies = ["httpx"]
# ///
# Decal asset id -> underlying Image id (via Open Cloud asset-delivery). T-057d.
import os, re, sys, httpx
sys.path.insert(0, os.path.dirname(__file__))
if "PROMPTQL_PLATFORM_API_URL" in os.environ:
    B = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com"
    H = {"Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"], "X-PromptQL-Description": "Resolve decal asset ids to image ids (read-only)"}
else:
    from cloud_test import _load_env_key
    B = "https://apis.roblox.com"
    H = {"x-api-key": _load_env_key() or ""}
with httpx.Client(timeout=60, follow_redirects=False) as c:
    for did in sys.argv[1:]:
        r = c.get(f"{B}/asset-delivery-api/v1/assetId/{did}", headers=H)
        loc = None
        try:
            loc = r.json().get("location")
        except Exception:
            pass
        if not loc:
            print(did, "ERR", r.status_code, r.text[:200]); continue
        body = httpx.get(loc, timeout=60).content
        m = re.search(rb"(?:rbxassetid://|id=)(\d+)", body)
        print(did, "->", m.group(1).decode() if m else ("NOID " + body[:120].decode("latin1")))
