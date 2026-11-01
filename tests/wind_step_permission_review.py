"""Synthetic human review records; not owner authorization or actual permissions."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import wind_step_permission_review as review

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}
NOW = 2000000000


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.record = {"schema": 1, "kind": review.KIND, "integrationId": "roblox-open-cloud",
                       "target": copy.deepcopy(TARGET), "reviewedByOwnerUserId": TARGET["ownerUserId"],
                       "credentialBindingConfirmed": True, "publicationScope": "universe-places",
                       "publicationOperation": "Write", "historyScope": "universe.place:read",
                       "reviewedAt": NOW - 1, "expiresAt": NOW + 60,
                       "sourceReference": "SYNTHETIC-REVIEW-NOT-OWNER-AUTHORIZATION", "sourceSha256": "b" * 64}
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "review.json"

    def load(self, *, raw=None, pin=None, source_pin=None, now=NOW, target=TARGET):
        raw = raw if raw is not None else json.dumps(self.record).encode()
        self.path.write_bytes(raw)
        return review.load_review(self.path, pin if pin is not None else hashlib.sha256(raw).hexdigest(),
                                  target, now, reviewed_source_pin=source_pin if source_pin is not None else "b" * 64)

    def test_valid_consistency_is_not_authority(self):
        r = self.load()
        self.assertEqual(r["status"], "REVIEW_CONSISTENT_ONLY")
        self.assertTrue(r["reviewRecordConsistent"])
        for f in ("reviewerIdentityVerified", "writePermissionVerified", "publishReady",
                  "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(r[f], False)
        self.assertEqual(r["target"], TARGET)
        self.assertEqual(r["reviewedAt"], NOW - 1)
        self.assertEqual(r["expiresAt"], NOW + 60)
        self.assertEqual(r["reviewedSourceSha256"], "b" * 64)
        self.assertNotIn("SYNTHETIC", json.dumps(r))
        self.assertNotIn("sourceReference", r)

    def test_digest_pins_independent_and_strict(self):
        for pin in ("a" * 64, "B" * 64, "b" * 63, "b" * 65, "", True):
            with self.subTest(pin=pin), self.assertRaises(ValueError):
                self.load(pin=pin)
        for pin in ("a" * 64, "B" * 64, "b" * 63, "", True):
            with self.assertRaises(ValueError):
                self.load(source_pin=pin)

    def test_tampering_after_pin_refused(self):
        raw = json.dumps(self.record).encode()
        with self.assertRaises(ValueError):
            self.load(raw=raw+b" ", pin=hashlib.sha256(raw).hexdigest())

    def test_exact_schema_fields_and_no_key_material_field(self):
        for name in list(self.record):
            r = self.record.pop(name)
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.load()
            self.record[name] = r
        for name in ("apiKey", "cookie", "rawKey", "extra", "writePermissionVerified"):
            self.record[name] = "SYNTHETIC-NOT-A-SECRET"
            with self.assertRaises(ValueError):
                self.load()
            del self.record[name]

    def test_binding_owner_and_scopes_never_inferred(self):
        cases = {"schema": [True, 2, "1"], "kind": ["consent", None],
                 "integrationId": ["other-key", "", None], "credentialBindingConfirmed": [1, False, "true"],
                 "reviewedByOwnerUserId": [1, "123", None], "publicationScope": ["*", "universe.place:read"],
                 "publicationOperation": ["Read", "write", "*"], "historyScope": ["*", "universe-places"]}
        for field, values in cases.items():
            original = self.record[field]
            for value in values:
                self.record[field] = value
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    self.load()
            self.record[field] = original

    def test_production_or_mismatched_target_before_io(self):
        for field, value in (("universeId", "10773761715"), ("placeId", "95587500384127"),
                             ("ownerUserId", "1"), ("placeId", "../1")):
            with patch("builtins.open", side_effect=AssertionError("must not open")), self.assertRaises(ValueError):
                review.load_review(self.path, "a"*64, {**TARGET, field: value}, NOW, reviewed_source_pin="b"*64)
        for field, value in (("universeId", "123"), ("placeId", "456"), ("schema", True)):
            self.record["target"] = {**TARGET, field: value}
            with self.assertRaises(ValueError):
                self.load()

    def test_time_window_and_recheck_expiry(self):
        for issued, expires in ((NOW+1, NOW+60), (0, NOW+60), (True, NOW+60), (NOW-1, NOW),
                                (NOW-1, NOW-1), (NOW-1, NOW+86400), (NOW-1, float(NOW+60))):
            self.record.update(reviewedAt=issued, expiresAt=expires)
            with self.assertRaises(ValueError):
                self.load()
        self.record.update(reviewedAt=NOW, expiresAt=NOW+86400)
        self.assertTrue(self.load()["reviewRecordConsistent"])
        with self.assertRaises(ValueError):
            self.load(now=NOW+86400)
        for now in (True, float("nan"), float("inf"), 0, "now"):
            with self.assertRaises(ValueError):
                self.load(now=now)

    def test_source_reference_required_digest_and_controls(self):
        for value in (None, "", " ", " x", "x ", "a\nb", "a\x7fb", "x" * 1025):
            self.record["sourceReference"] = value
            with self.assertRaises(ValueError):
                self.load()
        self.record["sourceReference"] = "synthetic-reviewed-source"
        for value in (None, "", "X" * 64, "a" * 63):
            self.record["sourceSha256"] = value
            with self.assertRaises(ValueError):
                self.load()

    def test_bounded_strict_json(self):
        for raw in (b"", b"[]", b"null", b"\xff", b" "*(review.MAX_REVIEW+1),
                    b'{"schema":1,"schema":2}', b'{"schema":NaN}'):
            with self.subTest(raw=raw[:40]), self.assertRaises((ValueError, UnicodeError)):
                self.load(raw=raw)

    def test_wrong_publication_consent_is_not_permission_review(self):
        self.record["kind"] = "Owner consent for isolated test overwrite and publication"
        self.record["authorizeTestPublication"] = True
        with self.assertRaises(ValueError):
            self.load()


class AttestationTests(ReviewTests):
    """Run the same hostile legacy suite after a truthful conversion, not relabeling."""
    def load(self, **kwargs):
        # Conversion is test-fixture-only; production has no auto-upgrade path.
        record = self.record
        self.record = copy.deepcopy(record)
        if self.record.get("schema") == 1 and type(self.record["schema"]) is int:
            self.record["schema"] = 2
        if self.record.get("kind") == review.KIND:
            self.record["kind"] = review.ATTESTATION_KIND
        for old, new in (("reviewedByOwnerUserId", "attestedByOwnerUserId"), ("reviewedAt", "attestedAt")):
            if old in self.record:
                self.record[new] = self.record.pop(old)
        self.record.setdefault("dashboardEvidenceWaived", True)
        try:
            return super().load(**kwargs)
        finally:
            self.record = record

    def test_valid_consistency_is_not_authority(self):
        r = self.load()
        self.assertEqual(r["status"], "OWNER_ATTESTATION_CONSISTENT_ONLY")
        self.assertEqual(r["permissionEvidenceType"], "OWNER_ATTESTATION")
        self.assertEqual(r["attestedAt"], NOW - 1)
        self.assertNotIn("reviewedAt", r)
        self.assertNotIn("sourceReference", r)
        for f in ("reviewerIdentityVerified", "writePermissionVerified", "publishReady",
                  "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(r[f], False)

    def test_binding_owner_and_scopes_never_inferred(self):
        # 2 is this format's valid version; all other inherited invalid inputs stay invalid.
        for value in (True, 0, 3, "2"):
            self.record["schema"] = value
            with self.assertRaises(ValueError):
                self.load()
        self.record["schema"] = 1
        for field, values in {"integrationId": ["other-key", "", None],
                              "credentialBindingConfirmed": [1, False, "true"],
                              "reviewedByOwnerUserId": [1, "123", None],
                              "publicationScope": ["*", "universe.place:read"],
                              "publicationOperation": ["Read", "write", "*"],
                              "historyScope": ["*", "universe-places"]}.items():
            old = self.record[field]
            for value in values:
                self.record[field] = value
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    self.load()
            self.record[field] = old

    def test_explicit_waiver_and_no_dashboard_impersonation(self):
        for value in (False, 1, "true", None):
            self.record["dashboardEvidenceWaived"] = value
            with self.assertRaises(ValueError):
                self.load()
        self.record["dashboardEvidenceWaived"] = True
        # Wrong kind/version cannot silently turn a declaration into a dashboard review.
        self.record["schema"] = 2
        raw = json.dumps(self.record).encode()
        with self.assertRaises(ValueError):
            super(AttestationTests, self).load(raw=raw)

    def test_attestation_required_fields_and_strict_schema(self):
        record = {**self.record, "schema": 2, "kind": review.ATTESTATION_KIND,
                  "dashboardEvidenceWaived": True}
        record["attestedAt"] = record.pop("reviewedAt")
        record["attestedByOwnerUserId"] = record.pop("reviewedByOwnerUserId")
        review.validate_review(record, TARGET, NOW)
        for kind in (review.KIND, "consent", "", None):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                review.validate_review({**record, "kind": kind}, TARGET, NOW)
        for version in (True, 1, 3, "2"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                review.validate_review({**record, "schema": version}, TARGET, NOW)
        for waiver in (False, 1, "true", None):
            with self.assertRaises(ValueError):
                review.validate_review({**record, "dashboardEvidenceWaived": waiver}, TARGET, NOW)
        for field in record:
            with self.subTest(field=field), self.assertRaises(ValueError):
                review.validate_review({k: v for k, v in record.items() if k != field}, TARGET, NOW)
        for field in ("reviewedAt", "reviewedByOwnerUserId", "dashboardInspected", "apiKey"):
            with self.assertRaises(ValueError):
                review.validate_review({**record, field: True}, TARGET, NOW)


if __name__ == "__main__":
    unittest.main()
