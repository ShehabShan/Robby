"""Synthetic offline composition: real staged RBXL + local Git journal. NO Roblox calls."""
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import transact_wind_step_publication as tx
import wind_step_intent_journal as journal
import stage_wind_step_published as staging
class LocalStore(journal.GitStore):
    def validate_remote(self):
        url = self.git('config', '--get', 'remote.origin.url').decode().strip()
        if Path(url).resolve() != self.repo.parent / 'remote.git':
            raise ValueError('test remote mismatch')

TARGET = {'schema': 1, 'kind': 'Robby isolated published test', 'universeId': '123456',
          'placeId': '654321', 'ownerUserId': '7738981129'}
NOW = 2000000000


class TransactionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        built = staging.stage(TARGET, enable_local_test=True)
        cls.manifest = Path(built['manifest']).read_bytes()
        cls.place = Path(built['place']).read_bytes()
        cls.head = json.loads(cls.manifest)['sourceRevision']

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='robby-transaction-test-', dir=ROOT.parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.spool = self.root / 'durable'
        self.spool.mkdir()
        remote, repo = self.root / 'remote.git', self.root / 'vm'
        for args in [('init', '--bare', '-q', str(remote)), ('clone', '-q', str(remote), str(repo)),
                     ('-C', str(repo), 'config', 'user.name', 'Synthetic'),
                     ('-C', str(repo), 'config', 'user.email', 'test@example.invalid')]:
            subprocess.run(['git', *args], check=True, capture_output=True)
        self.store = LocalStore(repo)
        self.state = {'branch': 'main', 'head': self.head, 'remoteHead': self.head, 'dirty': False}
        self.remote = {'path': 'universes/123456', 'rootPlace': 'universes/123456/places/654321',
                       'user': 'users/7738981129', 'visibility': 'PRIVATE'}
        self.inputs = {}
        self.put('manifest', self.manifest)
        self.put('place', self.place)
        self.put('source', b'SYNTHETIC REDACTED DASHBOARD REVIEW; NOT GENUINE AUTHORIZATION')
        self.consent = {'schema': 1, 'kind': 'Owner consent for isolated test overwrite and publication',
                        'target': dict(TARGET), 'manifestSha256': self.inputs['manifest'][1],
                        'placeSha256': self.inputs['place'][1], 'ownerUserId': TARGET['ownerUserId'],
                        'authorizeTestPublication': True, 'acknowledgeOverwrite': True,
                        'issuedAt': NOW - 10, 'expiresAt': NOW + 1000, 'sourceReference': 'SYNTHETIC OWNER SOURCE'}
        self.review = {'schema': 1, 'kind': tx.review.KIND, 'integrationId': 'roblox-open-cloud',
                       'target': dict(TARGET), 'reviewedByOwnerUserId': TARGET['ownerUserId'],
                       'credentialBindingConfirmed': True, 'publicationScope': 'universe-places',
                       'publicationOperation': 'Write', 'historyScope': 'universe.place:read',
                       'reviewedAt': NOW - 10, 'expiresAt': NOW + 1000,
                       'sourceReference': 'SYNTHETIC DASHBOARD SOURCE', 'sourceSha256': self.inputs['source'][1]}
        self.put('consent', json.dumps(self.consent).encode())
        self.put('review', json.dumps(self.review).encode())
        self.now = NOW
        self.posts = []
        self.targets = []
        self.pages = []

    def use_attestation(self):
        self.put('source', b'SYNTHETIC OWNER DECLARATION AND SCREENSHOT WAIVER; NO DASHBOARD INSPECTION')
        self.review.update(schema=2, kind=tx.review.ATTESTATION_KIND, dashboardEvidenceWaived=True,
                           sourceReference='SYNTHETIC OWNER ATTESTATION', sourceSha256=self.inputs['source'][1])
        self.review['attestedAt'] = self.review.pop('reviewedAt')
        self.review['attestedByOwnerUserId'] = self.review.pop('reviewedByOwnerUserId')
        self.put('review', json.dumps(self.review).encode())

    def test_owner_attestation_preserved_through_one_shot_transaction(self):
        self.use_attestation()
        receipt = self.run_tx()
        self.assertEqual(receipt['status'], 'HISTORY_CONFIRMED')
        self.assertEqual(len(self.posts), 1)
        self.assertIs(receipt['writePermissionVerified'], False)
        record = json.loads((self.evidence / 'review').read_bytes())
        self.assertEqual(record['kind'], tx.review.ATTESTATION_KIND)
        self.assertNotIn('reviewedAt', record)
        with self.assertRaises((ValueError, FileExistsError)):
            self.run_tx()
        self.assertEqual(len(self.posts), 1)

    def test_attestation_expiry_after_reservation_refuses_post(self):
        self.use_attestation()
        with self.after_reserve(lambda _: setattr(self, 'now', self.review['expiresAt'])):
            receipt = self.run_tx()
        self.assertEqual(receipt['status'], 'REJECTED')
        self.assertFalse(self.posts)
        self.assertTrue(journal.inspect(self.inputs['consent'][1], self.store)['consumed'])

    def put(self, name, raw):
        path = self.root / (name + '.input')
        path.write_bytes(raw)
        self.inputs[name] = (path, staging.sha(raw))

    def clock(self):
        self.now += 1
        return self.now

    def target(self, universe):
        self.targets.append(universe)
        return copy.deepcopy(self.remote)

    def post(self, target, data):
        # Intent and snapshot are durable and exact BEFORE POST.
        record = journal.inspect(self.inputs['consent'][1], self.store)
        self.assertTrue(record['consumed'])
        self.assertEqual((self.spool / self.inputs['consent'][1] / 'intent.json').exists(), True)
        self.assertEqual((self.evidence / 'place').read_bytes(), data)
        self.posts.append((target, data))
        return b'{"versionNumber":7}'

    def page(self, target, cursor):
        self.pages.append((target, cursor))
        return b'{"placeVersions":[{"version":7,"isPublished":true}],"hasMore":false}'

    @property
    def evidence(self):
        return self.spool / ('evidence-' + self.inputs['consent'][1])

    def run_tx(self, **kwargs):
        defaults = dict(owner_sources_reviewed=True, inspect=lambda: copy.deepcopy(self.state),
                        read_target=self.target, post=self.post, read_page=self.page,
                        clock=self.clock, store=self.store)
        defaults.update(kwargs)
        return tx.transact(self.inputs, self.spool, **defaults)

    def after_reserve(self, action):
        original = journal.reserve
        def reserve(*a, **kw):
            ticket = original(*a, **kw)
            action(ticket)
            return ticket
        return patch.object(journal, 'reserve', side_effect=reserve)

    def test_exact_success_keeps_evidence_and_never_claims_serving_or_readiness(self):
        receipt = self.run_tx()
        self.assertEqual(receipt['status'], 'HISTORY_CONFIRMED')
        self.assertEqual(receipt['version'], 7)
        self.assertEqual(self.posts, [(TARGET, self.place)])
        self.assertEqual(len(self.targets), 4)
        self.assertEqual(len(self.pages), 1)
        for name, (_, pin) in self.inputs.items():
            self.assertEqual(staging.sha((self.evidence / name).read_bytes()), pin)
        self.assertEqual((self.evidence / 'upload-response.json').read_bytes(), b'{"versionNumber":7}')
        self.assertEqual(staging.sha((self.evidence / 'history.json').read_bytes()), receipt['historySha256'])
        self.assertEqual(json.loads((self.evidence / 'receipt.json').read_bytes()), receipt)
        for field in ('publishReady', 'releaseEvidenceAccepted', 'dynamicsAccepted', 'retryAllowed',
                      'currentServingVersionVerified', 'writePermissionVerified', 'reviewerIdentityVerified'):
            self.assertIs(receipt[field], False)

    def test_explicit_operator_ack_required(self):
        with self.assertRaises(ValueError):
            self.run_tx(owner_sources_reviewed=False)
        self.assertFalse(self.posts or self.targets)

    def test_dirty_branch_remote_and_detached_refuse_before_snapshot(self):
        for key, value in [('branch', 'session/S99'), ('branch', ''), ('dirty', True), ('remoteHead', 'a'*40)]:
            with self.subTest(key=key, value=value):
                old = self.state[key]
                self.state[key] = value
                with self.assertRaises(ValueError):
                    self.run_tx()
                self.state[key] = old
        self.assertFalse(self.posts or self.targets)

    def test_each_independent_pin_refuses(self):
        for key in self.inputs:
            with self.subTest(key=key):
                old = self.inputs[key]
                self.inputs[key] = (old[0], '0'*64)
                with self.assertRaises(ValueError):
                    self.run_tx()
                self.inputs[key] = old
        self.assertFalse(self.posts or self.targets)

    def test_staged_source_revision_must_be_current_main(self):
        self.state['head'] = self.state['remoteHead'] = 'b'*40
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertFalse(self.posts or self.targets)

    def test_private_owner_root_required(self):
        self.remote['visibility'] = 'PUBLIC'
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertFalse(self.posts)
        self.assertIsNone(self.store.head(journal.intent_ref(self.inputs['consent'][1])))

    def test_expired_consent_refuses(self):
        self.consent['expiresAt'] = NOW
        self.put('consent', json.dumps(self.consent).encode())
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertFalse(self.posts or self.targets)

    def test_unbound_review_refuses(self):
        self.review['sourceSha256'] = 'f'*64
        self.put('review', json.dumps(self.review).encode())
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertFalse(self.posts or self.targets)

    def test_post_reservation_branch_race_is_consumed_rejection(self):
        with self.after_reserve(lambda _: self.state.update(branch='other')):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(result['dispatched'] or self.posts)
        with self.assertRaises(FileExistsError):
            self.run_tx(inspect=lambda: dict(self.state, branch='main'))

    def test_post_reservation_staleness_is_consumed_rejection(self):
        with self.after_reserve(lambda _: setattr(self, 'now', NOW + 121)):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_post_reservation_clock_reversal_refuses(self):
        with self.after_reserve(lambda _: setattr(self, 'now', NOW - 10)):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_post_reservation_source_swap_refuses(self):
        with self.after_reserve(lambda _: self.inputs['place'][0].write_bytes(b'changed')):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_post_reservation_snapshot_swap_refuses(self):
        with self.after_reserve(lambda _: (self.evidence / 'place').write_bytes(b'changed')):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_post_reservation_owner_change_refuses(self):
        with self.after_reserve(lambda _: self.remote.update(user='users/42')):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_consumed_remote_consent_never_dispatches_from_second_spool(self):
        self.run_tx()
        self.spool = self.root / 'second-durable'
        self.spool.mkdir()
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertEqual(len(self.posts), 1)

    def test_lost_post_ack_is_uncertain_and_never_retried(self):
        def timeout(target, data):
            self.post(target, data)
            raise TimeoutError('SECRET DO NOT PERSIST')
        result = self.run_tx(post=timeout)
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertIsNone(result['version'])
        self.assertEqual(len(self.posts), 1)
        self.assertFalse(self.pages)
        self.assertNotIn('SECRET', json.dumps(result))

    def test_malformed_response_is_uncertain_without_history(self):
        def bad(target, data):
            self.post(target, data)
            return b'{"versionNumber":true}'
        result = self.run_tx(post=bad)
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertFalse(self.pages)
        self.assertFalse((self.evidence / 'upload-response.json').exists())

    def test_unknown_response_fields_not_persisted(self):
        result = self.run_tx(post=lambda *_: b'{"versionNumber":7,"secret":"no"}')
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertFalse((self.evidence / 'upload-response.json').exists())

    def test_missing_history_is_uncertain(self):
        result = self.run_tx(read_page=lambda *_: b'{"placeVersions":[],"hasMore":false}')
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertIsNone(result['version'])
        self.assertTrue((self.evidence / 'history.json').exists())
        self.assertEqual(len(self.posts), 1)

    def test_history_timeout_is_uncertain(self):
        def fail(*_):
            raise TimeoutError('no')
        result = self.run_tx(read_page=fail)
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertEqual(len(self.posts), 1)

    def test_main_changed_after_post_is_not_history_confirmed(self):
        def change(target, data):
            raw = self.post(target, data)
            self.state['head'] = self.state['remoteHead'] = 'c'*40
            return raw
        result = self.run_tx(post=change)
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertIsNone(result['historySha256'])

    def test_evidence_fsync_failure_before_post_leaves_consumed_rejection(self):
        original = journal.write_once
        def write(path, raw):
            if path.name == 'pre-dispatch.json':
                raise OSError('disk failure')
            return original(path, raw)
        with patch.object(journal, 'write_once', side_effect=write):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_history_evidence_fsync_failure_is_uncertain(self):
        original = journal.write_once
        def write(path, raw):
            if path.name == 'history.json':
                raise OSError('disk failure')
            return original(path, raw)
        with patch.object(journal, 'write_once', side_effect=write):
            result = self.run_tx()
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertEqual(len(self.posts), 1)

    def test_terminal_write_failure_cannot_replay(self):
        with patch.object(journal, 'finish', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                self.run_tx()
        with self.assertRaises(FileExistsError):
            self.run_tx()
        self.assertEqual(len(self.posts), 1)

    def test_reservation_readback_failure_never_dispatches(self):
        with patch.object(self.store, 'read', side_effect=ValueError('readback failed')):
            with self.assertRaises(ValueError):
                self.run_tx()
        self.assertFalse(self.posts)
        self.assertTrue(journal.inspect(self.inputs['consent'][1], self.store)['consumed'])

    def test_snapshot_write_failure_never_reserves(self):
        with patch.object(journal, 'write_once', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                self.run_tx()
        self.assertFalse(self.posts)
        self.assertIsNone(self.store.head(journal.intent_ref(self.inputs['consent'][1])))

    def test_no_temp_or_repository_spool(self):
        for spool in (ROOT / 'build', Path(tempfile.gettempdir())):
            with self.subTest(spool=str(spool)), self.assertRaises(ValueError):
                tx.snapshot(self.inputs, spool)
        self.assertFalse(self.posts)

    def test_expiry_during_reservation_rejects(self):
        self.consent['expiresAt'] = NOW + 12
        self.put('consent', json.dumps(self.consent).encode())
        with self.after_reserve(lambda _: setattr(self, 'now', NOW + 15)):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_review_expiry_during_reservation_rejects(self):
        self.review['expiresAt'] = NOW + 12
        self.put('review', json.dumps(self.review).encode())
        with self.after_reserve(lambda _: setattr(self, 'now', NOW + 15)):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_last_checkout_change_refuses_dispatch(self):
        original = journal.write_once
        def write(path, raw):
            original(path, raw)
            if path.name == 'pre-dispatch.json':
                self.state['dirty'] = True
        with patch.object(journal, 'write_once', side_effect=write):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_last_artifact_change_refuses_dispatch(self):
        original = journal.write_once
        def write(path, raw):
            original(path, raw)
            if path.name == 'pre-dispatch.json':
                self.inputs['source'][0].write_bytes(b'replaced')
        with patch.object(journal, 'write_once', side_effect=write):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_final_journal_readback_refuses_dispatch(self):
        original = self.store.read
        calls = []
        def read(ref):
            calls.append(ref)
            value = original(ref)
            if len(calls) == 2:
                return ('f'*40, value[1])
            return value
        with patch.object(self.store, 'read', side_effect=read):
            result = self.run_tx()
        self.assertEqual(result['status'], 'REJECTED')
        self.assertFalse(self.posts)

    def test_mutation_during_post_cannot_confirm_history(self):
        def post(target, data):
            response = self.post(target, data)
            (self.evidence / 'source').write_bytes(b'changed')
            return response
        result = self.run_tx(post=post)
        self.assertEqual(result['status'], 'UNCERTAIN')
        self.assertIsNone(result['historySha256'])

    def test_snapshot_read_limits_empty_and_oversize(self):
        path = self.root / 'bounded-evidence'
        for raw in (b'', b'12345'):
            path.write_bytes(raw)
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                tx.read_bytes(path, 4)
        path.write_bytes(b'1234')
        self.assertEqual(tx.read_bytes(path, 4), b'1234')

    def test_exact_snapshot_package_validation_not_only_hashes(self):
        manifest = json.loads(self.manifest)
        manifest['publishReady'] = True
        self.put('manifest', json.dumps(manifest).encode())
        self.consent['manifestSha256'] = self.inputs['manifest'][1]
        self.put('consent', json.dumps(self.consent).encode())
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertFalse(self.posts or self.targets)

    def test_crash_after_dispatched_post_leaves_consumed_intent(self):
        def crash(target, data):
            self.post(target, data)
            raise SystemExit(73)  # deliberately not caught as a normal transport failure
        with self.assertRaises(SystemExit):
            self.run_tx(post=crash)
        self.assertTrue(journal.inspect(self.inputs['consent'][1], self.store)['consumed'])
        self.assertFalse((self.evidence / 'receipt.json').exists())
        self.spool = self.root / 'new-vm-durable'
        self.spool.mkdir()
        with self.assertRaises(ValueError):
            self.run_tx()
        self.assertEqual(len(self.posts), 1)

    def test_retained_snapshot_is_private_directory(self):
        self.run_tx()
        self.assertEqual(self.evidence.stat().st_mode & 0o777, 0o700)


class UploadTests(unittest.TestCase):
    def run_upload(self, status=200, raw=b'{"versionNumber":7}', error=None):
        class Response(io.BytesIO):
            pass
        response = Response(raw)
        response.status = status
        with patch.dict(os.environ, {'PROMPTQL_PLATFORM_API_URL': 'https://proxy.invalid', 'PROMPTQL_USER_JWT': 'SECRET'}):
            with patch.object(tx.urllib.request, 'build_opener') as build:
                opener = build.return_value
                opener.open.side_effect = error
                opener.open.return_value = response
                try:
                    result = tx.upload(TARGET, b'EXACT BYTES')
                finally:
                    self.assertEqual(opener.open.call_count, 1)
                    request = opener.open.call_args.args[0]
                    self.assertEqual(request.full_url, 'https://proxy.invalid/v1/integration/roblox-open-cloud/apis.roblox.com/universes/v1/123456/places/654321/versions?versionType=Published')
                    self.assertEqual(request.get_method(), 'POST')
                    self.assertEqual(request.data, b'EXACT BYTES')
                    self.assertEqual(opener.open.call_args.kwargs['timeout'], 600)
                    self.assertIsInstance(build.call_args.args[0], tx.gates.NoRedirect)
                return result

    def test_fixed_request_exact_body_no_redirect_retry(self):
        self.assertEqual(self.run_upload(), b'{"versionNumber":7}')

    def test_ambiguous_statuses_and_large_body_never_retry(self):
        for status in (201, 302, 400, 401, 403, 429, 500):
            with self.subTest(status=status), self.assertRaisesRegex(ValueError, 'never retry'):
                self.run_upload(status=status)
        with self.assertRaises(ValueError):
            self.run_upload(raw=b'x'*(tx.MAX_RESPONSE+1))

    def test_transport_error_is_sanitized(self):
        for error in (TimeoutError('SECRET'), urllib.error.HTTPError('secret', 403, 'SECRET', {}, io.BytesIO(b'SECRET'))):
            with self.assertRaisesRegex(ValueError, '^publication response uncertain; never retry$'):
                self.run_upload(error=error)

    def test_production_destination_never_opens_transport(self):
        target = dict(TARGET, universeId='10773761715', placeId='95587500384127')
        with patch.object(tx.urllib.request, 'build_opener') as build:
            with self.assertRaises(ValueError):
                tx.upload(target, b'bytes')
            build.assert_not_called()


if __name__ == '__main__':
    unittest.main()
