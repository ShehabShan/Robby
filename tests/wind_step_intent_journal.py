"""Offline protocol tests with a real local bare Git remote and independent clones.

All records are synthetic; no owner consent, GitHub journal or Roblox requests.
"""
import copy
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import wind_step_intent_journal as journal

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "123456",
          "placeId": "654321", "ownerUserId": "7738981129"}
NOW = 2000000000


def intent():
    return {"schema": 1, "kind": journal.INTENT_KIND, "target": copy.deepcopy(TARGET),
            "mainCommit": "a" * 40, "createdAt": NOW,
            **{field: str(i) * 64 for i, field in enumerate(sorted(journal.PINS), 1)}}


def outcome(ticket, status="UNCERTAIN"):
    return {"schema": 1, "kind": "WindStep isolated publication outcome",
            "intentSha256": journal.sha(ticket.intent_raw), "recordedAt": NOW + 1,
            "status": status, "version": 32 if status == "HISTORY_CONFIRMED" else None,
            "responseSha256": "b" * 64,
            "historySha256": "c" * 64 if status == "HISTORY_CONFIRMED" else None}


class LocalStore(journal.GitStore):
    # Production refuses local origins. Only test subclass allows our own bare repo.
    def validate_remote(self):
        url = self.git("config", "--get", "remote.origin.url").decode().strip()
        if Path(url).resolve() != self.repo.parent / "remote.git":
            raise ValueError("test remote mismatch")


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.cmd("init", "--bare", "--quiet", str(self.remote))
        self.stores = []
        self.spools = []
        for name in ("vm1", "vm2"):
            repo = self.root / name
            self.cmd("clone", "--quiet", str(self.remote), str(repo))
            self.cmd("-C", str(repo), "config", "user.name", "Synthetic Test")
            self.cmd("-C", str(repo), "config", "user.email", "test@example.invalid")
            self.stores.append(LocalStore(repo))
            spool = self.root / (name + "-durable")
            spool.mkdir()
            self.spools.append(spool)
        self.record = intent()
        self.ref = journal.intent_ref(self.record["consentSha256"])

    def cmd(self, *args):
        return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL)

    def reserve(self, vm=0, record=None):
        return journal.reserve(record or self.record, self.stores[vm], self.spools[vm])

    def assert_consumed(self):
        info = journal.inspect(self.record["consentSha256"], self.stores[1])
        self.assertTrue(info["consumed"])
        for flag in ("retryAllowed", "publishReady", "releaseEvidenceAccepted", "dynamicsAccepted"):
            self.assertIs(info[flag], False)
        return info

    def test_reservation_durable_and_readable_from_second_vm(self):
        ticket = self.reserve()
        info = self.assert_consumed()
        self.assertEqual(info["head"], ticket.head)
        self.assertEqual(info["records"]["intent.json"], json.loads(ticket.intent_raw))
        self.assertEqual((ticket.local / "intent.json").read_bytes(), ticket.intent_raw)
        self.assertEqual(json.loads((ticket.local / "reservation.json").read_text())["head"], ticket.head)
        self.assertEqual(self.cmd("-C", str(self.stores[0].repo), "status", "--porcelain"), b"")
        with self.assertRaises(Exception):
            self.reserve(1)

    def test_same_consent_changed_artifact_still_blocked(self):
        self.reserve()
        changed = copy.deepcopy(self.record)
        changed["manifestSha256"] = "f" * 64
        changed["placeSha256"] = "e" * 64
        changed["target"]["placeId"] = "654322"
        with self.assertRaises(ValueError):
            self.reserve(1, changed)

    def test_two_clone_simultaneous_race_only_one_ticket(self):
        barrier = threading.Barrier(2)
        for store in self.stores:
            real = store.head
            def synchronized(ref, real=real, state=[False]):
                value = real(ref)
                if not state[0]:
                    state[0] = True
                    barrier.wait(timeout=10)
                return value
            store.head = synchronized
        def attempt(vm):
            try:
                return self.reserve(vm)
            except ValueError:
                return None
        # Force identical Git dates so only the generated nonce distinguishes intents.
        dates = {"GIT_AUTHOR_DATE": "2000000000 +0000", "GIT_COMMITTER_DATE": "2000000000 +0000"}
        with patch.dict(os.environ, dates), ThreadPoolExecutor(max_workers=2) as executor:
            tickets = list(executor.map(attempt, (0, 1)))
        self.assertEqual(sum(t is not None for t in tickets), 1)
        # Even with identical inputs and commit timestamp, nonces prevent equal OIDs.
        raw = [(self.spools[i] / self.record["consentSha256"] / "intent.json").read_bytes() for i in range(2)]
        self.assertNotEqual(raw[0], raw[1])
        self.assert_consumed()

    def test_remote_push_accepted_then_connection_lost_no_ticket(self):
        real = self.stores[0].push
        def lost(*args):
            real(*args)
            raise ValueError("injected lost acknowledgment")
        with patch.object(self.stores[0], "push", side_effect=lost), self.assertRaises(ValueError):
            self.reserve()
        self.assert_consumed()
        with self.assertRaises(Exception):
            self.reserve()
        with self.assertRaises(ValueError):
            self.reserve(1)

    def test_fsync_intent_failure_never_pushes(self):
        with patch.object(journal.os, "fsync", side_effect=OSError("disk failure")), \
                patch.object(self.stores[0], "push") as push, self.assertRaises(OSError):
            self.reserve()
        push.assert_not_called()
        with self.assertRaises(FileExistsError):
            self.reserve()
        self.assertIsNone(self.stores[0].head(self.ref))

    def test_intent_write_failure_blocks_local_reentry(self):
        with patch.object(journal, "write_once", side_effect=OSError("disk failure")), \
                patch.object(self.stores[0], "push") as push, self.assertRaises(OSError):
            self.reserve()
        push.assert_not_called()
        with self.assertRaises(FileExistsError):
            self.reserve()

    def test_reservation_receipt_failure_is_consumed(self):
        real = journal.write_once
        def fail(path, raw):
            if path.name == "reservation.json":
                raise OSError("full disk")
            real(path, raw)
        with patch.object(journal, "write_once", side_effect=fail), self.assertRaises(OSError):
            self.reserve()
        self.assert_consumed()
        with self.assertRaises(ValueError):
            self.reserve(1)

    def test_remote_unavailable_no_ticket_or_retry(self):
        with patch.object(self.stores[0], "head", side_effect=ValueError("offline")), self.assertRaises(ValueError):
            self.reserve()
        with self.assertRaises(FileExistsError):
            self.reserve()

    def test_remote_readback_mismatch_no_ticket(self):
        with patch.object(self.stores[0], "read", return_value=("a" * 40, {})), self.assertRaises(ValueError):
            self.reserve()
        self.assert_consumed()

    def test_append_terminal_statuses_keep_original_intent(self):
        for i, status in enumerate(("REJECTED", "UNCERTAIN", "HISTORY_CONFIRMED")):
            record = copy.deepcopy(self.record)
            record["consentSha256"] = str(i + 7) * 64
            ticket = self.reserve(record=record)
            terminal = outcome(ticket, status)
            head = journal.finish(ticket, terminal, self.stores[0])
            info = journal.inspect(record["consentSha256"], self.stores[1])
            self.assertEqual(info["head"], head)
            self.assertEqual(info["records"]["outcome.json"], terminal)
            self.assertEqual(journal.encode(info["records"]["intent.json"]), ticket.intent_raw)
            self.assertEqual(self.cmd("-C", str(self.stores[0].repo), "rev-parse", head + "^").decode().strip(), ticket.head)
            with self.assertRaises(FileExistsError):
                journal.finish(ticket, terminal, self.stores[0])
            with self.assertRaises(ValueError):
                self.reserve(1, record)

    def test_outcome_fsync_failure_preserves_consumed_intent(self):
        ticket = self.reserve()
        with patch.object(journal.os, "fsync", side_effect=OSError("disk")), self.assertRaises(OSError):
            journal.finish(ticket, outcome(ticket), self.stores[0])
        self.assertEqual(set(self.assert_consumed()["records"]), {"intent.json"})
        with self.assertRaises(FileExistsError):
            journal.finish(ticket, outcome(ticket), self.stores[0])

    def test_terminal_push_lost_ack_still_readable_without_retry(self):
        ticket = self.reserve()
        real = self.stores[0].push
        def lost(*args):
            real(*args)
            raise ValueError("lost ack")
        with patch.object(self.stores[0], "push", side_effect=lost), self.assertRaises(ValueError):
            journal.finish(ticket, outcome(ticket), self.stores[0])
        self.assertEqual(self.assert_consumed()["records"]["outcome.json"]["status"], "UNCERTAIN")

    def test_terminal_remote_change_not_overwritten(self):
        ticket = self.reserve()
        raw = journal.encode(outcome(ticket, "REJECTED"))
        self.stores[1].read(ticket.ref)
        other = self.stores[1].commit(ticket.intent_raw, raw, parent=ticket.head)
        self.stores[1].push(ticket.ref, other, ticket.head)
        with self.assertRaises(ValueError):
            journal.finish(ticket, outcome(ticket), self.stores[0])
        self.assertEqual(self.assert_consumed()["records"]["outcome.json"]["status"], "REJECTED")

    def test_strict_intent_and_production_refusals(self):
        changes = [{"schema": True}, {"kind": "release authority"}, {"mainCommit": "A" * 40},
                   {"createdAt": True}, {"createdAt": 0}, {"createdAt": float("nan")},
                   {"consentSha256": "../escape"}, {"placeSha256": "g" * 64},
                   {"reviewSha256": ""}, {"reviewedSourceSha256": "A" * 64},
                   {"secret": "must not serialize"}, {"attemptNonce": "b" * 64}]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.reserve(record=dict(self.record, **change))
        for field, value in (("universeId", "10773761715"), ("placeId", "95587500384127"),
                             ("ownerUserId", "1")):
            record = copy.deepcopy(self.record)
            record["target"][field] = value
            with self.assertRaises(ValueError):
                self.reserve(record=record)
        self.assertIsNone(self.stores[0].head(self.ref))

    def test_strict_outcome_no_inferred_serving_or_secrets(self):
        ticket = self.reserve()
        base = outcome(ticket)
        for change in ({"intentSha256": "f" * 64}, {"recordedAt": NOW - 1}, {"recordedAt": True},
                       {"status": "PUBLISHED_CURRENT"}, {"status": "HISTORY_CONFIRMED"},
                       {"version": 42}, {"historySha256": "f" * 64}, {"apiKey": "never"},
                       {"responseSha256": "bad"}, {"schema": True}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                journal.finish(ticket, dict(base, **change), self.stores[0])
        self.assertFalse((ticket.local / "outcome.json").exists())

    def test_hostile_remote_tree_refused(self):
        raw = journal.encode(dict(self.record, attemptNonce="b" * 64, extra="secret"))
        head = self.stores[0].commit(raw)
        self.stores[0].push(self.ref, head, None)
        with self.assertRaises(ValueError):
            journal.inspect(self.record["consentSha256"], self.stores[1])
        with self.assertRaises(ValueError):
            self.reserve(1)

    def test_oversized_or_noncanonical_remote_json_refused(self):
        for i, raw in enumerate((b" " * (journal.MAX_RECORD + 1), b'{"schema":1,"schema":1}', b'{}')):
            ref = journal.intent_ref(str(i + 7) * 64)
            head = self.stores[0].commit(raw)
            self.stores[0].push(ref, head, None)
            with self.assertRaises(ValueError):
                self.stores[1].read(ref)

    def test_production_store_rejects_noncanonical_remote_and_pushurl(self):
        with self.assertRaises(ValueError):
            journal.GitStore(self.stores[0].repo)
        self.cmd("-C", str(self.stores[0].repo), "config", "remote.origin.url", "https://github.com/ShehabShan/Robby.git")
        journal.GitStore(self.stores[0].repo)  # no network calls
        self.cmd("-C", str(self.stores[0].repo), "config", "remote.origin.pushurl", str(self.remote))
        with self.assertRaises(ValueError):
            journal.GitStore(self.stores[0].repo)

    def test_order_fsync_before_remote_and_receipt_before_ticket(self):
        events = []
        sync = journal.os.fsync
        write = journal.write_once
        push = self.stores[0].push
        def fsync(fd):
            events.append("fsync")
            return sync(fd)
        def writing(path, raw):
            result = write(path, raw)
            events.append(path.name)
            return result
        def pushing(*args):
            events.append("push")
            self.assertIn("intent.json", events)
            self.assertGreaterEqual(events.count("fsync"), 3)
            return push(*args)
        with patch.object(journal.os, "fsync", side_effect=fsync), \
                patch.object(journal, "write_once", side_effect=writing), \
                patch.object(self.stores[0], "push", side_effect=pushing):
            self.reserve()
        self.assertLess(events.index("intent.json"), events.index("push"))
        self.assertLess(events.index("push"), events.index("reservation.json"))

    def test_real_process_death_after_remote_push_blocks_other_vm(self):
        child = """
import os, runpy, sys
m = runpy.run_path(sys.argv[1])
j = m['journal']
store = m['LocalStore'](sys.argv[2])
real = store.push
def die(*args):
    real(*args)
    os._exit(71)
store.push = die
j.reserve(m['intent'](), store, sys.argv[3])
"""
        r = subprocess.run([sys.executable, "-B", "-c", child, __file__, str(self.stores[0].repo),
                            str(self.spools[0])], capture_output=True, timeout=30)
        self.assertEqual(r.returncode, 71, r.stderr.decode())
        self.assert_consumed()
        with self.assertRaises(ValueError):
            self.reserve(1)
        self.assertFalse((self.spools[0] / self.record["consentSha256"] / "reservation.json").exists())

    def test_real_process_death_after_intent_fsync_blocks_local_replay(self):
        child = """
import os, runpy, sys
m = runpy.run_path(sys.argv[1])
j = m['journal']
real = j.write_once
def die(path, raw):
    real(path, raw)
    if path.name == 'intent.json': os._exit(72)
j.write_once = die
j.reserve(m['intent'](), m['LocalStore'](sys.argv[2]), sys.argv[3])
"""
        r = subprocess.run([sys.executable, "-B", "-c", child, __file__, str(self.stores[0].repo),
                            str(self.spools[0])], capture_output=True, timeout=30)
        self.assertEqual(r.returncode, 72, r.stderr.decode())
        self.assertTrue((self.spools[0] / self.record["consentSha256"] / "intent.json").is_file())
        with self.assertRaises(FileExistsError):
            self.reserve()
        self.assertIsNone(self.stores[0].head(self.ref))  # no remote write ever began

    def test_rewritten_or_multi_generation_terminal_history_refused(self):
        ticket = self.reserve()
        first = journal.finish(ticket, outcome(ticket), self.stores[0])
        # Even valid JSON cannot change/extend a terminal outcome chain.
        other = self.stores[0].commit(ticket.intent_raw, journal.encode(outcome(ticket)), parent=first)
        self.stores[0].push(ticket.ref, other, first)
        with self.assertRaises(ValueError):
            self.assert_consumed()

    def test_terminal_cannot_rewrite_original_intent(self):
        ticket = self.reserve()
        changed = json.loads(ticket.intent_raw)
        changed["placeSha256"] = "f" * 64
        terminal = outcome(ticket)
        terminal["intentSha256"] = journal.sha(journal.encode(changed))
        other = self.stores[0].commit(journal.encode(changed), journal.encode(terminal), parent=ticket.head)
        self.stores[0].push(ticket.ref, other, ticket.head)
        with self.assertRaises(ValueError):
            self.assert_consumed()

    def test_terminal_without_prior_intent_root_refused(self):
        ticket = self.reserve()
        other = self.stores[0].commit(ticket.intent_raw, journal.encode(outcome(ticket)))
        self.stores[0].push(ticket.ref, other, ticket.head)
        with self.assertRaises(ValueError):
            self.assert_consumed()

    def test_ref_cannot_claim_other_consent(self):
        raw = journal.validate_intent(dict(self.record, attemptNonce="b" * 64))
        wrong_ref = journal.intent_ref("f" * 64)
        head = self.stores[0].commit(raw)
        self.stores[0].push(wrong_ref, head, None)
        with self.assertRaises(ValueError):
            self.stores[1].read(wrong_ref)
        with self.assertRaises(ValueError):
            journal.inspect("f" * 64, self.stores[1])

    def test_terminal_compare_and_swap_closes_check_to_push_race(self):
        ticket = self.reserve()
        real = self.stores[0].push
        def concurrent(ref, head, expected):
            # Another durable terminal appears after finish has read its parent.
            rival = self.stores[0].commit(ticket.intent_raw, journal.encode(outcome(ticket, "REJECTED")),
                                          parent=ticket.head)
            real(ref, rival, ticket.head)
            real(ref, head, expected)
        with patch.object(self.stores[0], "push", side_effect=concurrent), self.assertRaises(ValueError):
            journal.finish(ticket, outcome(ticket), self.stores[0])
        self.assertEqual(self.assert_consumed()["records"]["outcome.json"]["status"], "REJECTED")

    def test_remote_unavailable_after_accepted_outcome_is_not_retryable(self):
        ticket = self.reserve()
        real = self.stores[0].read
        count = [0]
        def failed(ref):
            count[0] += 1
            if count[0] == 2:
                raise ValueError("readback unavailable")
            return real(ref)
        with patch.object(self.stores[0], "read", side_effect=failed), self.assertRaises(ValueError):
            journal.finish(ticket, outcome(ticket), self.stores[0])
        self.assertIn("outcome.json", self.assert_consumed()["records"])
        with self.assertRaises(FileExistsError):
            journal.finish(ticket, outcome(ticket), self.stores[0])

    def test_oversized_object_not_materialized(self):
        self.reserve()
        real = self.stores[1].git
        reads = []
        def inflated(*args, **kwargs):
            reads.append(args)
            if args[:2] == ("cat-file", "-s"):
                return str(journal.MAX_RECORD + 1).encode()
            return real(*args, **kwargs)
        with patch.object(self.stores[1], "git", side_effect=inflated), self.assertRaises(ValueError):
            self.stores[1].read(self.ref)
        self.assertFalse(any(args[0] == "show" for args in reads))

    def test_real_process_death_after_terminal_fsync_keeps_reservation(self):
        child = """
import os, runpy, sys
m = runpy.run_path(sys.argv[1])
j = m['journal']
store = m['LocalStore'](sys.argv[2])
ticket = j.reserve(m['intent'](), store, sys.argv[3])
real = j.write_once
def die(path, raw):
    real(path, raw)
    if path.name == 'outcome.json': os._exit(73)
j.write_once = die
j.finish(ticket, m['outcome'](ticket), store)
"""
        r = subprocess.run([sys.executable, "-B", "-c", child, __file__, str(self.stores[0].repo),
                            str(self.spools[0])], capture_output=True, timeout=30)
        self.assertEqual(r.returncode, 73, r.stderr.decode())
        self.assertEqual(set(self.assert_consumed()["records"]), {"intent.json"})
        self.assertTrue((self.spools[0] / self.record["consentSha256"] / "outcome.json").is_file())
        with self.assertRaises(ValueError):
            self.reserve(1)

    def test_missing_spool_never_creates_remote_intent(self):
        with self.assertRaises(ValueError):
            journal.reserve(self.record, self.stores[0], self.root / "missing")
        self.assertIsNone(self.stores[0].head(self.ref))

    def test_remote_target_switch_during_reservation_refused(self):
        # The production implementation rechecks its configured remote at push time.
        repo = self.stores[0].repo
        self.cmd("-C", str(repo), "config", "remote.origin.url", "https://github.com/ShehabShan/Robby.git")
        store = journal.GitStore(repo)
        self.cmd("-C", str(repo), "config", "remote.origin.url", "https://github.com/someone/else.git")
        with self.assertRaises(ValueError):
            store.push(self.ref, "a" * 40, None)
        with self.assertRaises(ValueError):
            store.read(self.ref)


if __name__ == "__main__":
    unittest.main()
