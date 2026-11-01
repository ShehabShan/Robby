"""Read-only test release preflight. ALWAYS BLOCKED for publication in this slice.

Requires clean synchronized main, an independently pinned staged artifact and a
separately reviewed/pinned owner consent record. GET privacy/root checks do NOT
prove write permission, empty contents, or the version serving players.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.request

import stage_wind_step_published as staging
from test_target import validate_config, validate_remote
from ingest_wind_step_evidence import strict_json

ROOT = Path(__file__).resolve().parents[1]
require = staging.require
MAX_CONSENT = 8192
MAX_RESPONSE = 1024 * 1024
MAX_AGE = 86400
MAX_PREFLIGHT = 120
CONSENT_FIELDS = {"schema", "kind", "target", "manifestSha256", "placeSha256", "ownerUserId",
                  "authorizeTestPublication", "acknowledgeOverwrite", "issuedAt", "expiresAt", "sourceReference"}


def checkout():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=30).strip()
    # ls-remote confirms CURRENT main, not a potentially stale origin/main cache.
    return {"branch": git("branch", "--show-current"), "head": git("rev-parse", "HEAD"),
            "dirty": bool(git("status", "--porcelain", "--untracked-files=all")),
            "remoteHead": git("ls-remote", "origin", "refs/heads/main").split()[0]}


def validate_checkout(state):
    require(type(state) is dict and state.get("branch") == "main" and state.get("dirty") is False,
            "requires clean main; no session/detached/dirty checkout")
    head = state.get("head")
    require(type(head) is str and re.fullmatch(r"[a-f0-9]{40}", head) and state.get("remoteHead") == head,
            "main must match current remote main")
    return head


def validate_consent(consent, manifest, pin, now):
    require(type(consent) is dict and set(consent) == CONSENT_FIELDS, "unexpected consent fields")
    require(type(consent["schema"]) is int and consent["schema"] == 1
            and consent["kind"] == "Owner consent for isolated test overwrite and publication", "bad consent kind/schema")
    validate_config(consent["target"])
    require(consent["target"] == manifest["target"] and consent["ownerUserId"] == manifest["target"]["ownerUserId"],
            "consent target/owner mismatch")
    require(consent["manifestSha256"] == pin and consent["placeSha256"] == manifest["placeSha256"],
            "consent must bind exact independently pinned staged bytes")
    require(consent["authorizeTestPublication"] is True and consent["acknowledgeOverwrite"] is True,
            "explicit test publication AND overwrite consent required; no inferred empty contents")
    issued, expires = consent["issuedAt"], consent["expiresAt"]
    require(type(issued) is int and type(expires) is int and 0 < issued <= now < expires
            and 0 < expires - issued <= MAX_AGE, "consent expired, future-dated or too long-lived")
    source = consent["sourceReference"]
    require(type(source) is str and 1 <= len(source.strip()) <= 1024 and not any(ord(c) < 32 for c in source),
            "reviewable owner consent source required")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("preflight redirects refused")


def read_universe(universe):
    # Caller validates the target before reaching this single fixed GET endpoint.
    url = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com/cloud/v2/universes/" + universe
    request = urllib.request.Request(url, method="GET", headers={
        "Authorization": "Bearer " + os.environ["PROMPTQL_USER_JWT"],
        "X-PromptQL-Description": "Read-only private test release preflight; no upload or permission probe"})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
        require(response.status == 200, "unexpected preflight status")
        raw = response.read(MAX_RESPONSE + 1)
    require(len(raw) <= MAX_RESPONSE, "universe response exceeds byte limit")
    return strict_json(raw.decode("utf-8"))


def preflight(manifest_path, manifest_pin, place_path, consent_path, consent_pin,
              *, inspect=checkout, read=read_universe, clock=time.time):
    start = clock()
    head = validate_checkout(inspect())
    staging.digest(manifest_pin, "manifest pin")
    staging.digest(consent_pin, "consent pin")
    consent, raw_consent = staging.load(consent_path, MAX_CONSENT)
    require(staging.sha(raw_consent) == consent_pin, "pinned consent mismatch")
    manifest, raw_manifest = staging.load(manifest_path, staging.MAX_MANIFEST)
    require(staging.sha(raw_manifest) == manifest_pin, "pinned manifest mismatch")
    require(type(manifest) is dict, "manifest must be an object")
    validate_config(manifest.get("target"))
    validate_consent(consent, manifest, manifest_pin, start)
    stage_result = staging.verify(manifest_path, manifest_pin, place_path)
    # Read immediately before observation, never from a prior session's cache.
    remote = read(manifest["target"]["universeId"])
    target_result = validate_remote(manifest["target"], remote)
    require(validate_checkout(inspect()) == head, "checkout changed during preflight")
    end = clock()
    require(0 <= end - start <= MAX_PREFLIGHT, "stale/clock-reversed preflight")
    validate_consent(consent, manifest, manifest_pin, end)
    return {"schema": 1, "kind": "WindStep read-only release preflight", "status": "BLOCKED",
            "observedAt": end, "mainRevision": head, "target": manifest["target"],
            "targetStatus": target_result["status"], "manifestSha256": manifest_pin,
            "placeSha256": stage_result["placeSha256"], "consentSha256": consent_pin,
            "remoteObservationSha256": hashlib.sha256(json.dumps(remote, sort_keys=True, allow_nan=False).encode()).hexdigest(),
            "writePermissionVerified": False, "publicationVersionVerified": False,
            "publishReady": False, "releaseEvidenceAccepted": False, "dynamicsAccepted": False,
            "remaining": ["credential-safe write authorization verification",
                          "main-only upload transaction and independently verified version receipt",
                          "delivered-release evidence binding", "actual authorized test publication"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("manifest", "manifest-sha256", "place", "consent", "consent-sha256"):
        parser.add_argument("--" + flag, required=True)
    args = parser.parse_args()
    try:
        result = preflight(args.manifest, args.manifest_sha256, args.place, args.consent, args.consent_sha256)
        print(json.dumps(result, sort_keys=True))
        parser.exit(1, "BLOCKED: read-only preflight never authorizes upload\n")
    except (ValueError, KeyError, IndexError, OSError, subprocess.SubprocessError) as exc:
        parser.exit(2, "PREFLIGHT REFUSED: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
