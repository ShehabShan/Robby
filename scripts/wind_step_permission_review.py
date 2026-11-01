"""Offline, independently pinned HUMAN permission review; not key introspection.

The operator must independently review the authentic redacted source and confirm
it concerns the credential configured behind roblox-open-cloud. This validates
consistency only. No network, key material, permission probe or upload permit.
"""
import hashlib
import json
import re

from ingest_wind_step_evidence import require, strict_json
from test_target import validate_config

MAX_REVIEW = 8192
MAX_AGE = 86400
KIND = "Owner dashboard review of isolated test API permissions"
FIELDS = {"schema", "kind", "integrationId", "target", "reviewedByOwnerUserId",
          "credentialBindingConfirmed", "publicationScope", "publicationOperation",
          "historyScope", "reviewedAt", "expiresAt", "sourceReference", "sourceSha256"}


def digest(value):
    require(type(value) is str and re.fullmatch(r"[a-f0-9]{64}", value), "invalid independent digest")
    return value


def validate_review(review, target, now):
    validate_config(target)
    require(type(review) is dict and set(review) == FIELDS, "unexpected permission-review fields")
    require(type(review["schema"]) is int and review["schema"] == 1 and review["kind"] == KIND,
            "invalid permission-review kind/schema")
    validate_config(review["target"])
    require(review["target"] == target, "permission-review target mismatch")
    require(review["reviewedByOwnerUserId"] == target["ownerUserId"], "owner review required")
    require(review["integrationId"] == "roblox-open-cloud"
            and review["credentialBindingConfirmed"] is True, "exact broker credential review required")
    require(review["publicationScope"] == "universe-places"
            and review["publicationOperation"] == "Write"
            and review["historyScope"] == "universe.place:read", "exact publication/history scopes required")
    reviewed, expires = review["reviewedAt"], review["expiresAt"]
    require(type(now) in (int, float) and 0 < now < float("inf"), "invalid review clock")
    require(type(reviewed) is int and type(expires) is int and 0 < reviewed <= now < expires
            and 0 < expires - reviewed <= MAX_AGE, "review expired, future-dated or too long-lived")
    source = review["sourceReference"]
    require(type(source) is str and 1 <= len(source) <= 1024 and source == source.strip()
            and all(ord(c) >= 32 and ord(c) != 127 for c in source), "reviewable source reference required")
    digest(review["sourceSha256"])


def load_review(path, independent_pin, target, now, *, reviewed_source_pin):
    # Both pins come from independent operator review, never inferred from file contents.
    validate_config(target)
    digest(independent_pin)
    digest(reviewed_source_pin)
    with open(path, "rb") as stream:
        raw = stream.read(MAX_REVIEW + 1)
    require(0 < len(raw) <= MAX_REVIEW, "permission-review exceeds byte limit")
    require(hashlib.sha256(raw).hexdigest() == independent_pin, "pinned review mismatch")
    review = strict_json(raw.decode("utf-8"))
    validate_review(review, target, now)
    require(review["sourceSha256"] == reviewed_source_pin, "independently reviewed source mismatch")
    # Do not propagate the human free-text source or content into receipts/logs.
    return {"schema": 1, "kind": "WindStep scoped permission-review validation",
            "status": "REVIEW_CONSISTENT_ONLY", "target": dict(target),
            "integrationId": "roblox-open-cloud", "reviewSha256": independent_pin,
            "reviewedSourceSha256": reviewed_source_pin,
            "reviewedAt": review["reviewedAt"], "expiresAt": review["expiresAt"],
            "reviewRecordConsistent": True, "reviewerIdentityVerified": False,
            "writePermissionVerified": False, "publishReady": False,
            "releaseEvidenceAccepted": False, "dynamicsAccepted": False}
