"""Synthetic actual-stage -> transaction -> canonical local journal -> report binding tests."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import ingest_wind_step_release as intake
import wind_step_publication_transaction as fixture
import wind_step_evidence_intake as studio_fixture


class ReleaseIntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture.TransactionTests.setUpClass()

    def setUp(self):
        self.fx = fixture.TransactionTests()
        self.fx.setUp()
        if getattr(self, "attestation", False):
            self.fx.use_attestation()
        self.addCleanup(self.fx.doCleanups)
        self.receipt = self.fx.run_tx()
        self.evidence = self.fx.evidence
        self.pin = intake.staging.sha((self.evidence / 'receipt.json').read_bytes())
        self.report_path = self.fx.root / 'report.json'
        self.report, _ = studio_fixture.synthetic()
        manifest = json.loads(self.fx.manifest)
        target = fixture.TARGET
        self.report['kind'] = 'WindStep isolated published dynamics'
        self.report['target'] = {k: int(target[k]) for k in ('universeId', 'placeId', 'ownerUserId')}
        self.report['environment'].update(studio=False, universeId=int(target['universeId']),
            placeId=int(target['placeId']), playerUserId=int(target['ownerUserId']),
            jobId='SYNTHETIC-NOT-ROBLOX', placeVersion=7, sourceRevision=manifest['sourceRevision'],
            sourceHashes=json.dumps(manifest['sourceHashes']), generatedServerSha256=manifest['generatedServerSha256'])
        computed = intake.candidate.calculate(self.report)
        self.report.update({k: computed[k] for k in ('passed', 'expected', 'matrixPassed', 'remaining')})

    def bind(self, **kwargs):
        self.report_path.write_text(json.dumps(self.report))
        return intake.bind(self.report_path, self.evidence, kwargs.pop('receipt_pin', self.pin),
                           kwargs.pop('consent_pin', self.fx.inputs['consent'][1]),
                           store=self.fx.store, **kwargs)

    def test_exact_release_bound_not_physics_authenticity_or_serving(self):
        result = self.bind()
        self.assertEqual(result['status'], 'RELEASE_REPORT_BOUND_ONLY')
        self.assertTrue(result['firstSliceReportedPass'])
        self.assertEqual(result['passed'], 106)
        self.assertTrue(result['releaseBindingConsistent'])
        self.assertEqual(result['publishedVersion'], 7)
        self.assertEqual(result['receiptSha256'], self.pin)
        for key in ('releaseEvidenceAccepted', 'dynamicsAccepted', 'currentServingVersionVerified',
                    'downloadedBytesVerified', 'reportAuthenticityVerified', 'publishReady'):
            self.assertIs(result[key], False)
        self.assertIn('death/original-root replacement', result['remaining'])

    def test_wrong_independent_receipt_or_consent_pin(self):
        for kw in ({'receipt_pin': 'f'*64}, {'consent_pin': 'e'*64}):
            with self.subTest(kw=kw), self.assertRaises(ValueError):
                self.bind(**kw)

    def test_forged_rehashed_receipt_not_canonical(self):
        for key, value in [('version', 8), ('publishReady', True), ('dispatched', 1), ('terminalCommit', 'f'*40)]:
            receipt = dict(self.receipt, **{key: value})
            raw = intake.journal.encode(receipt)
            (self.evidence / 'receipt.json').write_bytes(raw)
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.bind(receipt_pin=intake.staging.sha(raw))

    def test_each_replaced_retained_artifact_rejected(self):
        for name in ('manifest', 'place', 'consent', 'review', 'source', 'history.json', 'upload-response.json'):
            path = self.evidence / name
            old = path.read_bytes()
            path.write_bytes(b'{}')
            try:
                with self.subTest(name=name), self.assertRaises(ValueError):
                    self.bind()
            finally:
                path.write_bytes(old)

    def test_wrong_or_stale_report_version(self):
        for version in (0, 6, 8, True):
            self.report['environment']['placeVersion'] = version
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.bind()

    def test_wrong_target_and_source_report(self):
        original = copy.deepcopy(self.report)
        for key, value in [('universeId', 77), ('placeId', 88), ('playerUserId', 42),
                           ('sourceRevision', 'b'*40), ('generatedServerSha256', 'd'*64), ('jobId', '')]:
            self.report = copy.deepcopy(original)
            self.report['environment'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.bind()

    def test_forged_pass_and_incomplete_reports_not_accepted(self):
        self.report['results'].pop()
        with self.assertRaises(ValueError):
            self.bind()
        computed = intake.candidate.calculate(self.report)
        self.report.update({k: computed[k] for k in ('passed', 'expected', 'matrixPassed', 'remaining')})
        result = self.bind()
        self.assertFalse(result['firstSliceReportedPass'])
        self.assertEqual(result['missing'], ['lifetime-100'])
        self.assertFalse(result['dynamicsAccepted'])

    def test_offline_or_no_player_report_rejected(self):
        self.report['environment']['studio'] = True
        with self.assertRaises(ValueError):
            self.bind()
        self.report['environment']['studio'] = False
        self.report['environment']['running'] = False
        with self.assertRaises(ValueError):
            self.bind()

    def test_remote_changed_during_intake_rejected(self):
        original = self.fx.store.read
        calls = []
        def read(ref):
            calls.append(ref)
            head, records = original(ref)
            return (head if len(calls) == 1 else 'e'*40, records)
        with patch.object(self.fx.store, 'read', side_effect=read):
            with self.assertRaises(ValueError):
                self.bind()

    def test_files_changed_during_policy_check_rejected(self):
        original = intake.candidate.review_report
        def review(*args):
            result = original(*args)
            (self.evidence / 'source').write_bytes(b'changed')
            return result
        with patch.object(intake.candidate, 'review_report', side_effect=review):
            with self.assertRaises(ValueError):
                self.bind()

    def test_pending_journal_is_not_release(self):
        original = self.fx.store.read
        def read(ref):
            head, records = original(ref)
            del records['outcome.json']
            return head, records
        with patch.object(self.fx.store, 'read', side_effect=read):
            with self.assertRaises(ValueError):
                self.bind()

    def test_uncertain_journal_is_not_release(self):
        original = self.fx.store.read
        def read(ref):
            head, records = original(ref)
            records['outcome.json'].update(status='UNCERTAIN', version=None, historySha256=None)
            return head, records
        with patch.object(self.fx.store, 'read', side_effect=read):
            with self.assertRaises(ValueError):
                self.bind()

    def test_disabled_manifest_cannot_be_accepted_by_release_package_verifier(self):
        # The enabled verifier itself is exercised by the actual transaction suite;
        # assert intake still calls it, never silently selecting the candidate route.
        with patch.object(intake.staging, 'verify', side_effect=ValueError('disabled package')) as verify:
            with self.assertRaises(ValueError):
                self.bind()
            verify.assert_called_once()


class AttestationReleaseIntakeTests(ReleaseIntakeTests):
    """The complete release-intake hostile suite also applies to owner declarations."""
    attestation = True


if __name__ == '__main__':
    unittest.main()
