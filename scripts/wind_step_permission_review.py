"""Offline, independently pinned owner permission evidence; not key introspection.

The operator must inspect an authentic dashboard review OR explicit owner
attestation/waiver for the credential behind roblox-open-cloud. This validates
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
ATTESTATION_KIND = "Owner declaration of isolated test API permissions; dashboard evidence waived"
FIELDS = {"schema", "kind", "integrationId", "target", "reviewedByOwnerUserId",
          "credentialBindingConfirmed", "publicationScope", "publicationOperation",
          "historyScope", "reviewedAt", "expiresAt", "sourceReference", "sourceSha256"}

ATTESTATION_FIELDS = (FIELDS - {"reviewedByOwnerUserId", "reviewedAt"}) | {
    "attestedByOwnerUserId", "attestedAt", "dashboardEvidenceWaived"}


def evidence_fields(review):
    require(type(review) is dict and type(review.get("schema")) is int, "invalid permission evidence schema")
    if review["schema"] == 1:
        require(set(review) == FIELDS and review["kind"] == KIND, "invalid dashboard-review fields/kind")
        return "reviewedByOwnerUserId", "reviewedAt", "DASHBOARD_REVIEW"
    require(review["schema"] == 2 and set(review) == ATTESTATION_FIELDS
            and review["kind"] == ATTESTATION_KIND and review["dashboardEvidenceWaived"] is True,
            "explicit owner attestation and dashboard waiver required")
    return "attestedByOwnerUserId", "attestedAt", "OWNER_ATTESTATION"


def digest(value):
    require(type(value) is str and re.fullmatch(r"[a-f0-9]{64}", value), "invalid independent digest")
    return value


def validate_review(review, target, now):
    validate_config(target)
    owner_field, time_field, _ = evidence_fields(review)
    validate_config(review["target"])
    require(review["target"] == target, "permission-review target mismatch")
    require(review[owner_field] == target["ownerUserId"], "owner review required")
    require(review["integrationId"] == "roblox-open-cloud"
            and review["credentialBindingConfirmed"] is True, "exact broker credential review required")
    require(review["publicationScope"] == "universe-places"
            and review["publicationOperation"] == "Write"
            and review["historyScope"] == "universe.place:read", "exact publication/history scopes required")
    reviewed, expires = review[time_field], review["expiresAt"]
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
    _, time_field, basis = evidence_fields(review)
    # Do not propagate the human free-text source or content into receipts/logs.
    return {"schema": review["schema"], "kind": "WindStep scoped permission-review validation",
            "status": "OWNER_ATTESTATION_CONSISTENT_ONLY" if basis == "OWNER_ATTESTATION" else "REVIEW_CONSISTENT_ONLY",
            "permissionEvidenceType": basis, "target": dict(target),
            "integrationId": "roblox-open-cloud", "reviewSha256": independent_pin,
            "reviewedSourceSha256": reviewed_source_pin,
            time_field: review[time_field], "expiresAt": review["expiresAt"],
            "reviewRecordConsistent": True, "reviewerIdentityVerified": False,
            "writePermissionVerified": False, "publishReady": False,
            "releaseEvidenceAccepted": False, "dynamicsAccepted": False}
