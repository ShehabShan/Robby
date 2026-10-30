"""T-006: publish build/Robby.rbxl as a Published (live) place version via the roblox-open-cloud integration.
Only run when the owner explicitly asks (AGENTS.md §6 Publishing). Usage: python3 scripts/publish.py"""
import json, os, sys, urllib.request, urllib.error

U, P = "10773761715", "95587500384127"
BASE = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com"
JWT = os.environ["PROMPTQL_USER_JWT"]


def game_version():
    """Robby's own version from src/shared/Version.luau (T-029); Roblox's versionNumber is just an upload counter."""
    import re
    src = open("src/shared/Version.luau").read()
    parts = [re.search(rf"Version\.{k} = (\d+)", src).group(1) for k in ("MAJOR", "MINOR", "PATCH")]
    return ".".join(parts)


def main():
    data = open("build/Robby.rbxl", "rb").read()
    req = urllib.request.Request(
        BASE + f"/universes/v1/{U}/places/{P}/versions?versionType=Published", data=data, method="POST",
        headers={"Authorization": f"Bearer {JWT}", "Content-Type": "application/octet-stream",
                 "X-PromptQL-Description": "Publish the Robby build live so the owner can test it in Roblox (owner asked)"})
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            res = json.loads(r.read() or b"{}")
            print("publish:", r.status, res)
            print(f"PUBLISHED game v{game_version()} (Roblox place version {res.get('versionNumber')}): "
                  f"https://www.roblox.com/games/{P}")
    except urllib.error.HTTPError as e:
        print("publish FAILED:", e.code, e.read().decode()[:500])
        sys.exit(1)


main()