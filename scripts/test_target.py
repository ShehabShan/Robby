"""Read-only preflight for the separate private Sober test universe. NEVER uploads.

Usage: python3 scripts/test_target.py path/to/target.json
The config is explicit, non-secret and has no production fallback.
"""
import argparse
import json
import os
from pathlib import Path
import re
import urllib.request

PRODUCTION_UNIVERSE = "10773761715"
PRODUCTION_PLACE = "95587500384127"
OWNER = "7738981129"
KIND = "Robby isolated published test"


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r"[1-9][0-9]{0,15}", value):
        raise ValueError("IDs must be canonical positive decimal strings")
    if int(value) > 9007199254740991:
        raise ValueError("ID exceeds exact Luau integer range")
    return value


def validate_config(config):
    if not isinstance(config, dict) or set(config) != {"schema", "kind", "universeId", "placeId", "ownerUserId"}:
        raise ValueError("Expected exact test-target fields")
    if type(config["schema"]) is not int or config["schema"] != 1 or config["kind"] != KIND:
        raise ValueError("Unknown test-target schema/kind")
    universe, place, owner = (identifier(config[k]) for k in ("universeId", "placeId", "ownerUserId"))
    if universe == PRODUCTION_UNIVERSE or place == PRODUCTION_PLACE:
        raise ValueError("REFUSED: production universe/place cannot be a test destination")
    if owner != OWNER:
        raise ValueError("Unexpected Roblox owner; review required")
    return universe, place, owner


def validate_remote(config, remote):
    universe, place, owner = validate_config(config)
    expected = {"path": f"universes/{universe}", "rootPlace": f"universes/{universe}/places/{place}",
                "user": f"users/{owner}", "visibility": "PRIVATE"}
    if not isinstance(remote, dict) or any(remote.get(k) != v for k, v in expected.items()) or remote.get("group"):
        raise ValueError("Test destination must be a PRIVATE, owner-owned universe with the exact root place")
    return {"status": "TARGET_VERIFIED_ONLY", "universeId": universe, "placeId": place,
            "ownerUserId": owner, "displayName": remote.get("displayName", ""),
            "publishReady": False, "dynamicsAccepted": False}


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON field: " + key)
        result[key] = value
    return result


def load_config(path):
    data = Path(path).read_bytes()
    if len(data) > 4096:
        raise ValueError("Target config is too large")
    config = json.loads(data, object_pairs_hook=no_duplicates)
    validate_config(config)
    return config


def read_universe(universe):
    url = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com/cloud/v2/universes/" + universe
    request = urllib.request.Request(url, method="GET", headers={
        "Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"],
        "X-PromptQL-Description": "Verify separate private Robby test destination; read only, no publication"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def preflight(config, read=read_universe):
    universe, _, _ = validate_config(config)  # refuse BEFORE even a read
    return validate_remote(config, read(universe))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target")
    args = parser.parse_args()
    try:
        print(json.dumps(preflight(load_config(args.target)), indent=2))
    except Exception as error:
        parser.exit(1, "TEST TARGET BLOCKED: " + str(error) + "\n")


if __name__ == "__main__":
    main()
