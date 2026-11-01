"""Offline tests with one retained live GET fixture; no network or publication."""
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import urllib.error
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import observe_wind_step_publication as history

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}
STATE = {"branch": "main", "head": "a" * 40, "remoteHead": "a" * 40, "dirty": False}
REMOTE = {"path": "universes/123456", "rootPlace": "universes/123456/places/654321",
          "user": "users/7738981129", "visibility": "PRIVATE"}


def page(versions=(7,), more=False, cursor=""):
    return json.dumps({"placeVersions": [{"version": n, "isPublished": True} for n in versions],
                       "hasMore": more, "nextCursor": cursor}).encode()


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.pages = [page()]
        self.time = 2000000000

    def clock(self):
        self.time += 1
        return self.time

    def read(self, target, cursor):
        self.calls.append((target, cursor))
        return self.pages.pop(0)

    def run_observe(self, **kw):
        defaults = dict(inspect=lambda: copy.deepcopy(STATE), read_target=lambda _: copy.deepcopy(REMOTE),
                        read_page=self.read, clock=self.clock)
        defaults.update(kw)
        return history.observe(TARGET, 7, **defaults)

    def test_exact_observation_never_permission_readiness_or_serving(self):
        self.pages = [page((10, 7, 11))]  # intentionally unsorted
        r = self.run_observe()
        self.assertEqual(r["status"], "PUBLICATION_HISTORY_OBSERVED")
        self.assertTrue(r["historicalPublicationObserved"])
        for field in ("currentServingVersionVerified", "writePermissionVerified", "publishReady",
                      "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(r[field], False)
        self.assertEqual(r["target"], TARGET)
        self.assertEqual(r["mainRevision"], STATE["head"])
        self.assertEqual(r["expectedVersion"], 7)
        self.assertEqual(len(r["pageSha256"][0]), 64)
        self.assertEqual(len(r["targetObservationSha256"]), 2)

    def test_complete_absence_is_not_observed_not_failure_or_success(self):
        for values in ((), (6, 8)):
            self.pages = [page(values)]
            r = self.run_observe()
            self.assertEqual(r["status"], "NOT_OBSERVED")
            self.assertFalse(r["historicalPublicationObserved"])

    def test_paginate_and_match_exact_version(self):
        self.pages = [page((20,), True, "abc+/=x?"), page((7,))]
        r = self.run_observe()
        self.assertEqual(r["status"], "PUBLICATION_HISTORY_OBSERVED")
        self.assertEqual([c for _, c in self.calls], ["", "abc+/=x?"])
        self.assertEqual(r["pagesRead"], 2)

    def test_truncation_never_positive_even_if_match_found(self):
        self.pages = [page((7 + i,), True, str(i)) for i in range(history.MAX_PAGES)]
        r = self.run_observe()
        self.assertEqual(len(self.calls), history.MAX_PAGES)
        self.assertEqual(r["status"], "UNCERTAIN")
        self.assertFalse(r["historicalPublicationObserved"])
        self.assertFalse(r["historyComplete"])

    def test_cursor_cycle_duplicate_and_changing_history_refused(self):
        for pages in ([page((7,), True, "x"), page((8,), True, "x")],
                      [page((7,), True, "x"), page((7,))], [page((7, 7))]):
            self.pages = pages
            with self.assertRaises(ValueError):
                self.run_observe()

    def test_bad_version_types_refused(self):
        for value in (True, False, 0, -1, 7.0, "7", None, 9007199254740992):
            with self.subTest(value=value), self.assertRaises(ValueError):
                history.observe(TARGET, value, read_page=self.read)
            if value != "7":
                with self.assertRaises(ValueError):
                    history.parse_page(page((value,)))
        self.assertEqual(self.calls, [])

    def test_canonical_history_decimal_strings_only(self):
        for value in ("1", "7", str(history.MAX_VERSION)):
            self.assertEqual(history.parse_page(page((value,)))[0], [int(value)])
        for value in ("", "0", "00", "07", "-7", "+7", "7.0", "7e0", " 7", "7 ",
                      "７", "٧", "7\n", "9007199254740992", "9" * 10000):
            with self.subTest(value=value[:30]), self.assertRaises(ValueError):
                history.parse_page(page((value,)))
        for values in ((7, "7"), ("7", 7), ("7", "7")):
            with self.assertRaises(ValueError):
                history.parse_page(page(values))
        self.pages = [page(("7",), True, "next"), page((7,))]
        with self.assertRaises(ValueError):
            self.run_observe()

    def test_retained_live_history_terminal_cursor_and_string_versions(self):
        raw = (ROOT / "tests/fixtures/wind_step_history_s102.json").read_bytes()
        versions, more, cursor = history.parse_page(raw)
        self.assertEqual(versions, [2, 1])
        self.assertIs(more, False)
        self.assertEqual(cursor, "version_2zwAAAZPvuHn_oTE")
        self.pages = [raw]
        result = history.observe(TARGET, 2, inspect=lambda: copy.deepcopy(STATE),
                                 read_target=lambda _: copy.deepcopy(REMOTE),
                                 read_page=self.read, clock=self.clock)
        self.assertEqual(result["status"], "PUBLICATION_HISTORY_OBSERVED")
        self.assertEqual(len(self.calls), 1)  # terminal cursor MUST NOT cause a second GET
        self.assertTrue(result["historyComplete"])
        for field in ("currentServingVersionVerified", "writePermissionVerified", "publishReady",
                      "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(result[field], False)

    def test_terminal_cursor_still_bounded_and_nonterminal_requires_cursor(self):
        self.assertEqual(history.parse_page(page((), False, "terminal")), ([], False, "terminal"))
        for raw in (page((7,), True, ""), page((), True, "next"),
                    page((7,), False, "x" * 2049), page((7,), False, "bad cursor")):
            with self.assertRaises(ValueError):
                history.parse_page(raw)

    def test_unsafe_target_refused_before_any_call(self):
        for field, value in (("universeId", "10773761715"), ("placeId", "95587500384127"),
                             ("placeId", "1/../../"), ("ownerUserId", "123"), ("schema", True)):
            target = {**TARGET, field: value}
            with self.assertRaises(ValueError):
                history.observe(target, 7, inspect=lambda: self.fail("inspection before target guard"))
            with self.assertRaises(ValueError):
                history.history_request(target, "")

    def test_bad_checkout_before_get(self):
        for field, value in (("branch", "session/S97"), ("branch", ""), ("dirty", True),
                             ("remoteHead", "b" * 40)):
            with self.assertRaises(ValueError):
                self.run_observe(inspect=lambda: {**STATE, field: value},
                                 read_target=lambda _: self.fail("read before checkout guard"))

    def test_checkout_race_and_private_owner_root_rechecked(self):
        states = iter([STATE, {**STATE, "head": "b" * 40, "remoteHead": "b" * 40}])
        with self.assertRaises(ValueError):
            self.run_observe(inspect=lambda: next(states))
        for field, value in (("visibility", "PUBLIC"), ("rootPlace", "universes/123456/places/1"),
                             ("user", "users/1"), ("group", "groups/1")):
            for fail_after in (False, True):
                self.pages = [page()]
                bad = {**REMOTE, field: value}
                reads = iter([REMOTE, bad] if fail_after else [bad])
                with self.assertRaises(ValueError):
                    self.run_observe(read_target=lambda _: next(reads))

    def test_clock_budget_and_midstream_reversal(self):
        for times in ([2000000000, 2000000121], [2000000000, 1999999999],
                      [2000000000, 2000000001, 2000000002, 2000000001], [float("nan")], [True]):
            values = iter(times)
            with self.assertRaises(ValueError):
                self.run_observe(clock=lambda: next(values))

    def test_strict_json_size_and_envelope(self):
        cases = [b"", b" " * (history.MAX_RESPONSE + 1), b"[]", b"null", b"\xff", b'{"a":1,"a":2}',
                 b'{"placeVersions":[],"hasMore":false,"x":NaN}', b'{"placeVersions":[],"hasMore":false,"hasMore":true}']
        base = json.loads(page())
        for field, value in (("hasMore", "false"), ("hasMore", 0), ("placeVersions", {}),
                             ("placeVersions", [None]), ("placeVersions", [{"version": 7}]),
                             ("placeVersions", [{"version": 7, "isPublished": False}]),
                             ("placeVersions", [{"version": 7, "isPublished": 1}]),
                             ("nextCursor", None), ("nextCursor", "\n"), ("nextCursor", "x" * 2049),
                             ("hasMore", True), ("extra", True)):
            cases.append(json.dumps({**base, field: value}).encode())
        cases += [page(tuple(range(1, 102))), page((), True, "x")]
        for raw in cases:
            with self.subTest(raw=raw[:80]), self.assertRaises((ValueError, UnicodeError)):
                history.parse_page(raw)

    def test_optional_empty_cursor_and_metadata_are_supported(self):
        raw = b'{"placeVersions":[{"version":7,"isPublished":true,"title":"ok","contributors":[]}],"hasMore":false}'
        self.assertEqual(history.parse_page(raw), ([7], False, ""))

    def test_request_is_get_only_encoded_fixed_proxy(self):
        with patch.dict(os.environ, {"PROMPTQL_PLATFORM_API_URL": "https://proxy.invalid", "PROMPTQL_USER_JWT": "SYNTHETIC"}):
            req = history.history_request(TARGET, "a+/=?&evil=x")
        self.assertEqual(req.get_method(), "GET")
        self.assertIsNone(req.data)
        parsed = urllib.parse.urlsplit(req.full_url)
        self.assertEqual(parsed.netloc, "proxy.invalid")
        self.assertEqual(parsed.path, "/v1/integration/roblox-open-cloud/apis.roblox.com/place-version-history-api/v1/654321/history")
        self.assertEqual(urllib.parse.parse_qs(parsed.query), {"cursor": ["a+/=?&evil=x"],
                                                             "isPublished": ["true"], "pageSize": ["100"]})
        self.assertEqual(req.get_header("Authorization"), "Bearer SYNTHETIC")
        self.assertIsNotNone(req.get_header("X-promptql-description"))
        self.assertNotIn("x-api-key", str(req.headers).lower())
        self.assertNotIn("cookie", str(req.headers).lower())

    def test_transport_bounds_status_no_retry_and_redaction(self):
        class Response(io.BytesIO):
            status = 200
        with patch.dict(os.environ, {"PROMPTQL_PLATFORM_API_URL": "https://proxy.invalid", "PROMPTQL_USER_JWT": "SYNTHETIC"}):
            with patch.object(history.urllib.request, "build_opener") as factory:
                factory.return_value.open.return_value = Response(page())
                self.assertEqual(history.read_history(TARGET, ""), page())
                factory.assert_called_once()
                self.assertIsInstance(factory.call_args.args[0], history.NoRedirect)
                self.assertEqual(factory.return_value.open.call_args.kwargs, {"timeout": 30})
            for response in (Response(b""), Response(b"x" * (history.MAX_RESPONSE + 1)), Response(page())):
                if len(response.getvalue()) == len(page()):
                    response.status = 201
                with patch.object(history.urllib.request, "build_opener") as factory:
                    factory.return_value.open.return_value = response
                    with self.assertRaises(ValueError):
                        history.read_history(TARGET, "")
                    self.assertEqual(factory.return_value.open.call_count, 1)
            for error in (TimeoutError("SECRET"), urllib.error.HTTPError("SECRET", 403, "SECRET", {}, None)):
                with patch.object(history.urllib.request, "build_opener") as factory:
                    factory.return_value.open.side_effect = error
                    with self.assertRaises(ValueError) as caught:
                        history.read_history(TARGET, "")
                    self.assertNotIn("SECRET", str(caught.exception))
                    self.assertEqual(factory.return_value.open.call_count, 1)

    def test_failed_read_never_retried(self):
        with patch.object(self, "read", side_effect=ValueError("refused")) as reader:
            with self.assertRaises(ValueError):
                self.run_observe(read_page=reader)
            reader.assert_called_once()

    def test_redirects_refused(self):
        with self.assertRaises(ValueError):
            history.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://evil.invalid")

    def test_cli_success_still_nonzero_no_readiness(self):
        with patch.object(sys, "argv", ["observer", "--target", "unused", "--expected-version", "7"]), \
             patch.object(history, "load_config", return_value=TARGET), \
             patch.object(history, "observe", return_value={"status": "PUBLICATION_HISTORY_OBSERVED", "publishReady": False}), \
             patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(history.main(), 1)
            self.assertFalse(json.loads(output.getvalue())["publishReady"])
        with patch.object(sys, "argv", ["observer", "--target", "unused", "--expected-version", "7"]), \
             patch.object(history, "load_config", side_effect=ValueError("SECRET")), \
             patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(history.main(), 2)
            self.assertNotIn("SECRET", output.getvalue())


if __name__ == "__main__":
    unittest.main()
