"""HTTP-free, create-only consent consumption for cooperating release VMs.

One consent digest owns one permanent Git ref. NEVER delete/reset/reclaim it.
A reservation is NOT release authority. Any interrupted/ambiguous operation is
consumed/uncertain; reading old records never returns a fresh execution ticket.
Repository administrators can defeat this protocol by rewriting refs: protect
publication-intent/* against deletion/force-push outside this implementation.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
from dataclasses import dataclass

from ingest_wind_step_evidence import require, strict_json
from test_target import validate_config
from wind_step_permission_review import digest

MAX_RECORD = 8192
INTENT_KIND = "WindStep isolated publication intent"
PINS = {"consentSha256", "manifestSha256", "placeSha256", "reviewSha256", "reviewedSourceSha256"}
FIELDS = PINS | {"schema", "kind", "target", "mainCommit", "createdAt", "attemptNonce"}
OUTCOME_FIELDS = {"schema", "kind", "intentSha256", "status", "recordedAt", "version",
                  "responseSha256", "historySha256"}
REPO_URLS = {"https://github.com/ShehabShan/Robby.git", "https://github.com/ShehabShan/Robby"}


def encode(record):
    raw = (json.dumps(record, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()
    require(len(raw) <= MAX_RECORD, "journal record exceeds bound")
    return raw


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def positive_time(value):
    require(type(value) is int and 0 < value <= 9007199254740991, "invalid journal timestamp")


def validate_intent(record):
    require(type(record) is dict and set(record) == FIELDS, "unexpected intent fields")
    require(type(record["schema"]) is int and record["schema"] == 1
            and record["kind"] == INTENT_KIND, "invalid intent schema/kind")
    validate_config(record["target"])
    for field in PINS:
        digest(record[field])
    require(type(record["mainCommit"]) is str and re.fullmatch(r"[a-f0-9]{40}", record["mainCommit"]),
            "invalid pinned main commit")
    digest(record["attemptNonce"])
    positive_time(record["createdAt"])
    return encode(record)


def validate_outcome(record, intent):
    require(type(record) is dict and set(record) == OUTCOME_FIELDS, "unexpected outcome fields")
    require(type(record["schema"]) is int and record["schema"] == 1
            and record["kind"] == "WindStep isolated publication outcome", "invalid outcome kind/schema")
    require(record["intentSha256"] == sha(validate_intent(intent)), "outcome intent mismatch")
    positive_time(record["recordedAt"])
    require(record["recordedAt"] >= intent["createdAt"], "outcome precedes intent")
    require(record["status"] in ("REJECTED", "UNCERTAIN", "HISTORY_CONFIRMED"), "invalid outcome status")
    for field in ("responseSha256", "historySha256"):
        if record[field] is not None:
            digest(record[field])
    if record["status"] == "HISTORY_CONFIRMED":
        require(type(record["version"]) is int and 0 < record["version"] <= 9007199254740991
                and record["historySha256"] is not None, "history outcome requires exact version/evidence pin")
    else:
        require(record["version"] is None and record["historySha256"] is None,
                "unconfirmed outcome must not imply publication version")
    return encode(record)


def intent_ref(consent_pin):
    return "refs/heads/publication-intent/" + digest(consent_pin)


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def write_once(path, raw):
    # No rename/overwrite: failed writes intentionally leave a blocking tombstone.
    with open(path, "xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    sync_dir(path.parent)


class GitStore:
    """Native git proxy transport, no credentials or upstream bodies in errors."""
    def __init__(self, repo):
        self.repo = Path(repo).resolve()
        self.validate_remote()

    def git(self, *args, data=None):
        try:
            result = subprocess.run(["git", *args], cwd=self.repo, input=data,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45, check=True)
            require(len(result.stdout) <= 32768, "oversized journal git response")
            return result.stdout
        except (subprocess.SubprocessError, OSError):
            raise ValueError("journal git operation failed; consumed/uncertain, do not retry") from None

    def validate_remote(self):
        url = self.git("config", "--get", "remote.origin.url").decode().strip()
        require(url in REPO_URLS, "journal requires canonical Robby origin")
        # A separate pushurl could send the reservation somewhere else.
        extra = subprocess.run(["git", "config", "--get-all", "remote.origin.pushurl"], cwd=self.repo,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        require(extra.returncode == 1 and not extra.stdout, "journal origin pushurl forbidden")

    def head(self, ref):
        raw = self.git("ls-remote", "--refs", "origin", ref).decode().strip()
        if not raw:
            return None
        parts = raw.split()
        require(len(parts) == 2 and re.fullmatch(r"[a-f0-9]{40}", parts[0]) and parts[1] == ref,
                "ambiguous journal remote ref")
        return parts[0]

    def commit(self, intent_raw, outcome_raw=None, parent=None):
        entries = []
        for name, raw in (("intent.json", intent_raw), ("outcome.json", outcome_raw)):
            if raw is not None:
                blob = self.git("hash-object", "-w", "--stdin", data=raw).decode().strip()
                entries.append(f"100644 blob {blob}\t{name}\n")
        tree = self.git("mktree", data="".join(entries).encode()).decode().strip()
        args = ["commit-tree", tree]
        if parent:
            args += ["-p", parent]
        return self.git(*args, data=b"Isolated publication journal (not release authority)\n").decode().strip()

    def push(self, ref, commit, expected):
        # Empty expected means create-only, not merely 'non-fast-forward denied'.
        self.validate_remote()
        self.git("push", "--porcelain", "--force-with-lease=" + ref + ":" + (expected or ""),
                 "origin", commit + ":" + ref)

    def tree_records(self, head):
        entries = self.git("ls-tree", head).decode().splitlines()
        names = []
        for entry in entries:
            match = re.fullmatch(r"100644 blob [a-f0-9]{40}\t(intent|outcome)\.json", entry)
            require(match is not None, "unexpected journal tree entry")
            names.append(match[1] + ".json")
        require(names in (["intent.json"], ["intent.json", "outcome.json"]), "unexpected journal tree")
        records = {}
        for name in names:
            size = int(self.git("cat-file", "-s", head + ":" + name))
            require(0 < size <= MAX_RECORD, "journal object exceeds bound")
            raw = self.git("show", head + ":" + name)
            record = strict_json(raw.decode("utf-8"))
            require(encode(record) == raw, "noncanonical journal record")
            records[name] = record
        validate_intent(records["intent.json"])
        if "outcome.json" in records:
            validate_outcome(records["outcome.json"], records["intent.json"])
        return records

    def parents(self, head):
        raw = self.git("rev-list", "--parents", "-n", "1", head).decode().split()
        require(raw and raw[0] == head and len(raw) <= 2, "unexpected journal ancestry")
        return raw[1:]

    def read(self, ref):
        require(re.fullmatch(r"refs/heads/publication-intent/[a-f0-9]{64}", ref), "invalid journal ref")
        self.validate_remote()
        head = self.head(ref)
        require(head is not None, "journal ref absent; absence is not permission to retry")
        self.git("fetch", "--quiet", "--no-tags", "origin", ref)
        fetched = self.git("rev-parse", "FETCH_HEAD").decode().strip()
        require(fetched == head and self.head(ref) == head, "journal changed during read")
        records = self.tree_records(head)
        require(intent_ref(records["intent.json"]["consentSha256"]) == ref, "journal ref/consent mismatch")
        parents = self.parents(head)
        if "outcome.json" in records:
            require(len(parents) == 1 and not self.parents(parents[0]), "outcome must be one child of root")
            original = self.tree_records(parents[0])
            require(original == {"intent.json": records["intent.json"]}, "original intent changed")
        else:
            require(not parents, "intent must be a root commit")
        require(self.head(ref) == head, "journal changed during verification")
        return head, records


@dataclass(frozen=True)
class Ticket:
    ref: str
    head: str
    intent_raw: bytes
    local: Path


def reserve(intent, store, spool):
    """Returns a new ticket only after fsync + create-CAS + exact remote readback.

    Caller must perform separate release gates. There is deliberately no resume,
    reclaim, retry or 'already exists but mine' success path.
    """
    require(type(intent) is dict and set(intent) == FIELDS - {"attemptNonce"}, "unexpected reservation input")
    # Distinct commits matter: Git can report an identical concurrent push as
    # up-to-date without applying its lease. Never let callers choose this nonce.
    intent = dict(intent, attemptNonce=secrets.token_hex(32))
    raw = validate_intent(intent)
    ref = intent_ref(intent["consentSha256"])
    spool = Path(spool).resolve()
    # Require a caller-created durable directory outside build/temporary outputs.
    require(spool.is_dir(), "durable journal directory must already exist")
    local = spool / intent["consentSha256"]
    local.mkdir()  # exclusive across local processes; even incomplete intent blocks reuse
    sync_dir(spool)
    write_once(local / "intent.json", raw)
    require(store.head(ref) is None, "consent already consumed; never retry")
    head = store.commit(raw)
    store.push(ref, head, None)
    observed, records = store.read(ref)
    require(observed == head and records == {"intent.json": intent}, "reservation readback mismatch")
    write_once(local / "reservation.json", encode({"ref": ref, "head": head, "intentSha256": sha(raw)}))
    return Ticket(ref, head, raw, local)


def finish(ticket, outcome, store):
    """Append one terminal outcome using exact-parent CAS; never rewrite intent.

    On any failure, the reservation remains consumed. Terminal records summarize
    independently checked evidence; this module does not verify remote publication.
    """
    intent = strict_json(ticket.intent_raw.decode())
    raw = validate_outcome(outcome, intent)
    require(ticket.ref == intent_ref(intent["consentSha256"]), "ticket consent mismatch")
    write_once(ticket.local / "outcome.json", raw)
    old_head, old_records = store.read(ticket.ref)
    require(old_head == ticket.head and old_records == {"intent.json": intent}, "terminal journal already changed")
    head = store.commit(ticket.intent_raw, raw, parent=ticket.head)
    store.push(ticket.ref, head, ticket.head)
    observed, records = store.read(ticket.ref)
    require(observed == head and records == {"intent.json": intent, "outcome.json": outcome},
            "outcome readback mismatch; consumed/uncertain")
    write_once(ticket.local / "terminal.json", encode({"head": head, "status": outcome["status"]}))
    return head


def inspect(consent_pin, store):
    """Read-only handoff. Every state is consumed; NEVER return an execution ticket."""
    head, records = store.read(intent_ref(consent_pin))
    require(records["intent.json"]["consentSha256"] == consent_pin, "remote consent mismatch")
    return {"head": head, "records": records, "consumed": True, "retryAllowed": False,
            "publishReady": False, "releaseEvidenceAccepted": False, "dynamicsAccepted": False}
