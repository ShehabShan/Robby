"""Offline preflight refusal tests. Injected GET; no Roblox credentials or writes."""
import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import preflight_wind_step_release as preflight
import stage_wind_step_published as staging

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}
NOW = 2000000000
HEAD = "a" * 40


class PreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.directory = Path(cls.temp.name)
        built = staging.stage(TARGET, enable_local_test=True)
        cls.manifest = cls.directory / "manifest.json"
        cls.place = cls.directory / "place.rbxl"
        cls.manifest.write_bytes(Path(built["manifest"]).read_bytes())
        cls.place.write_bytes(Path(built["place"]).read_bytes())
        cls.pin = built["manifestSha256"]
        cls.place_pin = built["placeSha256"]

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.consent = {"schema": 1, "kind": "Owner consent for isolated test overwrite and publication",
                        "target": dict(TARGET), "manifestSha256": self.pin, "placeSha256": self.place_pin,
                        "ownerUserId": TARGET["ownerUserId"], "authorizeTestPublication": True,
                        "acknowledgeOverwrite": True, "issuedAt": NOW - 10, "expiresAt": NOW + 60,
                        "sourceReference": "SYNTHETIC-OWNER-CONSENT-NOT-AUTHORIZATION"}
        self.checkout = {"branch": "main", "dirty": False, "head": HEAD, "remoteHead": HEAD}
        self.remote = {"path": "universes/123456", "rootPlace": "universes/123456/places/654321",
                       "user": "users/7738981129", "visibility": "PRIVATE"}
        self.calls = []
        self.clock_values = [NOW, NOW + 1]

    def read(self, universe):
        self.calls.append(universe)
        return self.remote

    def run_preflight(self, *, inspect=None, read=None, consent_pin=None, raw=None):
        raw = raw if raw is not None else json.dumps(self.consent).encode()
        path = self.directory / "consent.json"
        path.write_bytes(raw)
        times = iter(self.clock_values)
        return preflight.preflight(self.manifest, self.pin, self.place, path,
            consent_pin or staging.sha(raw), inspect=inspect or (lambda: self.checkout),
            read=read or self.read, clock=lambda: next(times))

    def test_fresh_get_remains_blocked_and_truthful(self):
        result = self.run_preflight()
        self.assertEqual(self.calls, ["123456"])
        self.assertEqual(result["status"], "BLOCKED")
        self.assertEqual(result["mainRevision"], HEAD)
        self.assertEqual(result["targetStatus"], "TARGET_VERIFIED_ONLY")
        for field in ("publishReady", "releaseEvidenceAccepted", "dynamicsAccepted", "writePermissionVerified",
                      "publicationVersionVerified"):
            self.assertIs(result[field], False)
        self.assertEqual(result["manifestSha256"], self.pin)

    def test_main_clean_and_synced_required_before_get(self):
        for field, value in (("branch", "session/S96"), ("branch", ""), ("dirty", True),
                             ("dirty", 0), ("head", "bad"), ("remoteHead", "b" * 40)):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.run_preflight(inspect=lambda: dict(self.checkout, **{field: value}))
        self.assertEqual(self.calls, [])

    def test_checkout_change_during_get(self):
        states = iter([self.checkout, dict(self.checkout, head="b" * 40, remoteHead="b" * 40)])
        with self.assertRaisesRegex(ValueError, "checkout changed"):
            self.run_preflight(inspect=lambda: next(states))

    def test_no_inferred_or_forged_authorization(self):
        changes = {"authorizeTestPublication": False, "acknowledgeOverwrite": False, "ownerUserId": "1",
                   "manifestSha256": "0" * 64, "placeSha256": "0" * 64, "schema": True,
                   "kind": "empty target", "sourceReference": "", "writePermissionVerified": True}
        for field, value in changes.items():
            original = copy.deepcopy(self.consent)
            self.consent[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_preflight()
            self.consent = original
        self.assertEqual(self.calls, [])

    def test_consent_target_and_production_refusal(self):
        for field, value in (("placeId", "999"), ("placeId", "95587500384127"),
                             ("universeId", "10773761715"), ("ownerUserId", "1")):
            self.consent["target"] = dict(TARGET, **{field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_preflight()
        self.assertEqual(self.calls, [])

    def test_consent_time_bounds(self):
        for issued, expires in ((NOW+1, NOW+60), (NOW-10, NOW), (NOW-10, NOW+86400),
                                (True, NOW+60), (NOW-10, float(NOW+60))):
            self.consent.update(issuedAt=issued, expiresAt=expires)
            with self.subTest(issued=issued, expires=expires), self.assertRaises(ValueError):
                self.run_preflight()
        self.assertEqual(self.calls, [])

    def test_consent_expires_during_preflight(self):
        self.clock_values = [NOW, NOW+61]
        with self.assertRaisesRegex(ValueError, "expired"):
            self.run_preflight()

    def test_preflight_age_and_clock_reversal(self):
        self.consent["expiresAt"] = NOW + 500
        for end in (NOW-1, NOW+121):
            self.clock_values = [NOW, end]
            with self.subTest(end=end), self.assertRaisesRegex(ValueError, "stale/clock"):
                self.run_preflight()

    def test_consent_pin_bounds_and_strict_json(self):
        with self.assertRaisesRegex(ValueError, "pinned consent"):
            self.run_preflight(consent_pin="0"*64)
        raw = json.dumps(self.consent).encode()
        for bad in (raw + b" "*(preflight.MAX_CONSENT+1-len(raw)), b'{"schema":1,"schema":1}', b'{"x":NaN}', b'\xff'):
            with self.subTest(raw=bad[:25]), self.assertRaises(ValueError):
                self.run_preflight(raw=bad)
        self.assertEqual(self.calls, [])

    def test_unsafe_remote_observations(self):
        for field, value in (("visibility", "PUBLIC"), ("rootPlace", "universes/123456/places/999"),
                             ("user", "users/1"), ("group", "groups/1"), ("path", "universes/999")):
            self.remote = {"path": "universes/123456", "rootPlace": "universes/123456/places/654321",
                           "user": "users/7738981129", "visibility": "PRIVATE", **{field: value}}
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_preflight()

    def test_get_failure_never_retries_or_writes(self):
        for code in (401,403,429,500):
            calls = []
            def fail(universe):
                calls.append(universe)
                raise urllib.error.HTTPError("SYNTHETIC", code, "refused", {}, None)
            with self.subTest(code=code), self.assertRaises(urllib.error.HTTPError):
                self.run_preflight(read=fail)
            self.assertEqual(calls, ["123456"])

    def test_stage_verification_precedes_get(self):
        with patch.object(staging, "verify", side_effect=ValueError("synthetic stage mismatch")):
            with self.assertRaisesRegex(ValueError, "stage mismatch"):
                self.run_preflight()
        self.assertEqual(self.calls, [])

    def test_http_adapter_refuses_oversize_duplicate_and_wrong_status(self):
        for raw, status in ((b" " * (preflight.MAX_RESPONSE + 1), 200),
                            (b'{"path":1,"path":2}', 200), (b'{"x":NaN}', 200),
                            (b'{}', 202), (b'\xff', 200)):
            class Response(io.BytesIO):
                pass
            response = Response(raw)
            response.status = status
            class Opener:
                def open(inner, request, timeout):
                    return response
            with self.subTest(status=status, size=len(raw)), \
                 patch.dict("os.environ", {"PROMPTQL_PLATFORM_API_URL":"https://synthetic.invalid",
                                           "PROMPTQL_USER_JWT":"synthetic-not-secret"}), \
                 patch.object(preflight.urllib.request, "build_opener", return_value=Opener()):
                with self.assertRaises(ValueError):
                    preflight.read_universe("123456")

    def test_actual_http_adapter_is_bounded_get_only(self):
        calls = []
        class Response(io.BytesIO):
            status = 200
        class Opener:
            def open(inner, request, timeout):
                calls.append((request.get_method(), request.full_url, request.data, timeout))
                return Response(json.dumps(self.remote).encode())
        with patch.dict("os.environ", {"PROMPTQL_PLATFORM_API_URL":"https://synthetic.invalid",
                                       "PROMPTQL_USER_JWT":"synthetic-not-secret"}), \
             patch.object(preflight.urllib.request, "build_opener", return_value=Opener()):
            self.assertEqual(preflight.read_universe("123456"), self.remote)
        self.assertEqual(calls, [("GET", "https://synthetic.invalid/v1/integration/roblox-open-cloud/apis.roblox.com/cloud/v2/universes/123456", None, 30)])
        with self.assertRaisesRegex(ValueError, "redirects"):
            preflight.NoRedirect().redirect_request(None,None,302,"",{},"https://elsewhere.invalid")


if __name__ == "__main__":
    unittest.main()
