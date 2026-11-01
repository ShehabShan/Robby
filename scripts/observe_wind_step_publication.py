"""GET-only isolated-test publication HISTORY observation; never serving proof.

No upload, retries, cookies, key introspection, or write authorization. The
experimental history API's isPublished field describes historical publication,
not the version in a particular running server. Live CLI requires clean main.
"""
import argparse
import hashlib
import json
import os
import re
import time
import urllib.parse
import urllib.request

from ingest_wind_step_evidence import require, strict_json
from preflight_wind_step_release import checkout, validate_checkout, NoRedirect, read_universe
from test_target import load_config, validate_config, validate_remote

MAX_RESPONSE = 1024 * 1024
MAX_PAGES = 4
PAGE_SIZE = 100
MAX_SECONDS = 120
MAX_VERSION = 9007199254740991


def version_number(value):
    require(type(value) is int and 0 < value <= MAX_VERSION, "invalid exact version number")
    return value


def history_version_number(value):
    # Live history GET (S102) returns decimal strings; upload/caller contracts
    # remain strict integers. Bound before int() and reject alternate spellings.
    if type(value) is str:
        require(re.fullmatch(r"[1-9][0-9]{0,15}", value) is not None,
                "invalid history version string")
        value = int(value)
    return version_number(value)


def cursor_value(value):
    require(type(value) is str and len(value) <= 2048
            and all(33 <= ord(c) <= 126 for c in value), "invalid history cursor")
    return value


def history_request(target, cursor):
    _, place, _ = validate_config(target)
    cursor_value(cursor)
    query = {"isPublished": "true", "pageSize": str(PAGE_SIZE)}
    if cursor:
        query["cursor"] = cursor
    url = (os.environ["PROMPTQL_PLATFORM_API_URL"]
           + "/v1/integration/roblox-open-cloud/apis.roblox.com/place-version-history-api/v1/"
           + place + "/history?" + urllib.parse.urlencode(query))
    return urllib.request.Request(url, method="GET", headers={
        "Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"],
        "X-PromptQL-Description": "Observe isolated test publication history; GET only, not serving-version proof"})


def read_history(target, cursor):
    request = history_request(target, cursor)
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
            require(response.status == 200, "unexpected history status")
            raw = response.read(MAX_RESPONSE + 1)
        require(0 < len(raw) <= MAX_RESPONSE, "history response exceeds byte limit")
        return raw
    except Exception:
        # Do not echo proxy URLs, headers, response bodies, or credentials.
        raise ValueError("history GET refused or unavailable; no retry performed") from None


def parse_page(raw):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_RESPONSE, "bad history response size/type")
    page = strict_json(raw.decode("utf-8"))
    require(type(page) is dict and set(page) <= {"placeVersions", "hasMore", "nextCursor"}
            and {"placeVersions", "hasMore"} <= set(page), "unexpected history envelope")
    rows, more, cursor = page["placeVersions"], page["hasMore"], page.get("nextCursor", "")
    require(type(rows) is list and len(rows) <= PAGE_SIZE and type(more) is bool, "bad history rows/pagination")
    cursor_value(cursor)
    # Live API retains a cursor even on the last page. hasMore is the
    # pagination authority; validate terminal cursors but never follow them.
    require(not more or (bool(cursor) and len(rows) > 0), "inconsistent history cursor")
    versions = []
    for row in rows:
        require(type(row) is dict and {"version", "isPublished"} <= set(row), "bad history row")
        version = history_version_number(row["version"])
        require(type(row["isPublished"]) is bool and row["isPublished"] is True,
                "unpublished/malformed row in published-only history")
        require(version not in versions, "duplicate version within page")
        versions.append(version)
    return versions, more, cursor


def observe(target, expected_version, *, inspect=checkout, read_target=read_universe,
            read_page=read_history, clock=time.time):
    # Copy/validate exact IDs before ANY external request, even injected ones.
    validate_config(target)
    target = dict(target)
    version_number(expected_version)
    start = previous = clock()
    require(type(start) in (int, float) and 0 < start < float("inf"), "invalid observation clock")

    def tick():
        nonlocal previous
        now = clock()
        require(type(now) in (int, float) and previous <= now <= start + MAX_SECONDS,
                "stale/clock-reversed history observation")
        previous = now
        return now

    head = validate_checkout(inspect())
    tick()
    before = read_target(target["universeId"])
    validate_remote(target, before)
    tick()
    versions, cursors, hashes = set(), set(), []
    cursor = ""
    complete = False
    for _ in range(MAX_PAGES):
        tick()
        raw = read_page(dict(target), cursor)
        tick()
        numbers, more, next_cursor = parse_page(raw)
        require(not versions.intersection(numbers), "duplicate version across pages; history changed")
        versions.update(numbers)
        hashes.append(hashlib.sha256(raw).hexdigest())
        if not more:
            complete = True
            break
        require(next_cursor not in cursors, "history cursor loop")
        cursors.add(next_cursor)
        cursor = next_cursor
    # A truncated scan cannot certify absence or produce a successful observation.
    tick()
    after = read_target(target["universeId"])
    validate_remote(target, after)
    tick()
    require(validate_checkout(inspect()) == head, "checkout changed during observation")
    end = tick()
    matched = complete and expected_version in versions
    return {"schema": 1, "kind": "WindStep publication history observation",
            "status": ("PUBLICATION_HISTORY_OBSERVED" if matched else
                       "NOT_OBSERVED" if complete else "UNCERTAIN"),
            "target": target, "expectedVersion": expected_version, "mainRevision": head,
            "startedAt": start, "observedAt": end, "historyComplete": complete,
            "pagesRead": len(hashes), "versionsInspected": len(versions),
            "pageSha256": hashes,
            "targetObservationSha256": [hashlib.sha256(json.dumps(x, sort_keys=True, allow_nan=False).encode()).hexdigest()
                                        for x in (before, after)],
            "historicalPublicationObserved": matched,
            "currentServingVersionVerified": False, "writePermissionVerified": False,
            "publishReady": False, "releaseEvidenceAccepted": False, "dynamicsAccepted": False,
            "remaining": ["one-shot authorized transaction and exact-byte receipt",
                          "running-player report bound to delivered release/version",
                          "actual dynamics and device evidence"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True)
    parser.add_argument("--expected-version", required=True, type=int)
    args = parser.parse_args()
    try:
        result = observe(load_config(args.target), args.expected_version)
    except Exception:
        print(json.dumps({"status": "BLOCKED", "reason": "history observation refused or unavailable",
                          "publishReady": False, "currentServingVersionVerified": False}))
        return 2
    print(json.dumps(result, sort_keys=True, allow_nan=False))
    # This command can never be a successful upload/readiness gate.
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
