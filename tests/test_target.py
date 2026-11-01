"""Offline safety tests. No Roblox writes or API calls."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("target", ROOT / "scripts/test_target.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class TestTarget(unittest.TestCase):
    def setUp(self):
        self.config = {"schema": 1, "kind": target.KIND, "universeId": "123", "placeId": "456", "ownerUserId": target.OWNER}
        self.remote = {"path": "universes/123", "rootPlace": "universes/123/places/456", "visibility": "PRIVATE", "user": "users/" + target.OWNER}

    def test_private_exact_target_is_not_publish_or_physics_acceptance(self):
        result = target.preflight(self.config, lambda _: self.remote)
        self.assertEqual(result["status"], "TARGET_VERIFIED_ONLY")
        self.assertFalse(result["publishReady"])
        self.assertFalse(result["dynamicsAccepted"])

    def test_production_either_id_refused_before_network(self):
        for field, value in (("universeId", target.PRODUCTION_UNIVERSE), ("placeId", target.PRODUCTION_PLACE)):
            config = {**self.config, field: value}
            def must_not_call(_):
                self.fail("Production preflight reached network")
            with self.assertRaises(ValueError):
                target.preflight(config, must_not_call)

    def test_id_formats(self):
        for value in (None, True, 123, 0, "", "0", "01", "-1", "1.0", " 123", "123/places/456", "１２３", "9007199254740992"):
            for field in ("universeId", "placeId", "ownerUserId"):
                with self.subTest(value=value, field=field), self.assertRaises(ValueError):
                    target.validate_config({**self.config, field: value})

    def test_missing_extra_or_bad_fields(self):
        for field in self.config:
            config = dict(self.config)
            del config[field]
            with self.assertRaises(ValueError):
                target.validate_config(config)
        for patch in ({"schema": True}, {"schema": 2}, {"kind": "live"}, {"ownerUserId": "1"}, {"publish": True}):
            with self.assertRaises(ValueError):
                target.validate_config({**self.config, **patch})

    def test_remote_mismatch_or_missing_fields(self):
        for key in self.remote:
            for value in (None, "", "wrong"):
                remote = {**self.remote, key: value}
                with self.assertRaises(ValueError):
                    target.validate_remote(self.config, remote)
        for patch in ({"visibility": "PUBLIC"}, {"group": "groups/1"}, {"rootPlace": "universes/123/places/789"}):
            with self.assertRaises(ValueError):
                target.validate_remote(self.config, {**self.remote, **patch})

    def test_errors_fail_closed(self):
        def failed(_):
            raise PermissionError("scope denied")
        with self.assertRaises(PermissionError):
            target.preflight(self.config, failed)
        for remote in (None, [], {}, ""):
            with self.assertRaises(ValueError):
                target.validate_remote(self.config, remote)

    def test_no_mutation_or_fallback(self):
        before = copy.deepcopy((self.config, self.remote))
        calls = []
        target.preflight(self.config, lambda u: calls.append(u) or self.remote)
        self.assertEqual(calls, ["123"])
        self.assertEqual(before, (self.config, self.remote))

    def test_config_parser(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "target.json"
            for data in ('{"schema":1,"schema":2}', "{}", "x" * 4097, "not-json"):
                path.write_text(data)
                with self.assertRaises(ValueError):
                    target.load_config(path)


if __name__ == "__main__":
    unittest.main()
