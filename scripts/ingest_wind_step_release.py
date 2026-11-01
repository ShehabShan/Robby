"""Read-only retained-release/report binding. Never publish or accept dynamics from consistency."""
import argparse
import json
from pathlib import Path

import ingest_wind_step_published as candidate
import preflight_wind_step_release as gates
import stage_wind_step_published as staging
import transact_wind_step_publication as transaction
import wind_step_intent_journal as journal
import wind_step_permission_review as permissions
import observe_wind_step_publication as history

require = staging.require
FALSE_FLAGS = ('retryAllowed', 'currentServingVersionVerified', 'writePermissionVerified',
               'reviewerIdentityVerified', 'publishReady', 'releaseEvidenceAccepted', 'dynamicsAccepted')


def bind(report_path, evidence, receipt_pin, consent_pin, *, store=None):
    """Independent pins and canonical remote journal required, not a caller-supplied receipt alone.

    A terminal journal is trusted operator evidence, not Roblox cryptographic attestation.
    An authentic owner return still needs human review. No HTTP write exists here.
    """
    permissions.digest(receipt_pin)
    permissions.digest(consent_pin)
    evidence = Path(evidence)
    receipt, receipt_raw = candidate.load(evidence / 'receipt.json', journal.MAX_RECORD)
    require(staging.sha(receipt_raw) == receipt_pin, 'independent receipt pin mismatch')
    store = store if store is not None else journal.GitStore(staging.ROOT)
    store.validate_remote()
    remote_head, records = store.read(journal.intent_ref(consent_pin))
    require(set(records) == {'intent.json', 'outcome.json'}, 'completed canonical journal required')
    intent, outcome = records['intent.json'], records['outcome.json']
    journal.validate_intent(intent)
    journal.validate_outcome(outcome, intent)
    require(intent['consentSha256'] == consent_pin, 'wrong canonical consent')
    require(outcome['status'] == 'HISTORY_CONFIRMED', 'confirmed historical publication required')
    expected = dict(outcome, terminalCommit=remote_head, mainCommit=intent['mainCommit'], target=intent['target'],
                    **{key: intent[key] for key in journal.PINS}, dispatched=True,
                    **{key: False for key in FALSE_FLAGS})
    require(type(receipt) is dict and receipt == expected and set(receipt) == set(expected),
            'receipt differs from canonical intent/terminal')
    for key in FALSE_FLAGS:
        require(receipt[key] is False, 'receipt cannot claim readiness/verification')
    require(receipt['dispatched'] is True, 'completed dispatch required')

    bounds = {'manifest': staging.MAX_MANIFEST, 'place': staging.MAX_PLACE, 'consent': gates.MAX_CONSENT,
              'review': permissions.MAX_REVIEW, 'source': transaction.MAX_SOURCE}
    pins = {'manifest': 'manifestSha256', 'place': 'placeSha256', 'consent': 'consentSha256',
            'review': 'reviewSha256', 'source': 'reviewedSourceSha256'}
    retained = {}
    for name, maximum in bounds.items():
        retained[name] = transaction.read_bytes(evidence / name, maximum)
        require(staging.sha(retained[name]) == intent[pins[name]], 'retained evidence mismatch: ' + name)
    manifest = candidate.common.strict_json(retained['manifest'].decode())
    require(manifest['target'] == intent['target'] and manifest['sourceRevision'] == intent['mainCommit'],
            'staged revision/target differs from publication intent')
    staging.verify(evidence / 'manifest', intent['manifestSha256'], evidence / 'place')
    consent = candidate.common.strict_json(retained['consent'].decode())
    gates.validate_consent(consent, manifest, intent['manifestSha256'], intent['createdAt'])
    permissions.load_review(evidence / 'review', intent['reviewSha256'], intent['target'], intent['createdAt'],
                            reviewed_source_pin=intent['reviewedSourceSha256'])
    response, raw_response = candidate.load(evidence / 'upload-response.json', transaction.MAX_RESPONSE)
    require(staging.sha(raw_response) == outcome['responseSha256'], 'response digest differs from journal')
    require(type(response) is dict and set(response) == {'versionNumber'}, 'bad retained upload response')
    version = history.version_number(response['versionNumber'])
    require(version == outcome['version'], 'upload version differs from journal')
    observation, raw_history = candidate.load(evidence / 'history.json', journal.MAX_RECORD)
    require(staging.sha(raw_history) == outcome['historySha256'], 'history digest differs from journal')
    require(observation.get('schema') == 1 and observation.get('kind') == 'WindStep publication history observation'
            and observation.get('status') == 'PUBLICATION_HISTORY_OBSERVED'
            and observation.get('historicalPublicationObserved') is True
            and observation.get('historyComplete') is True, 'unconfirmed retained history')
    require(observation.get('target') == intent['target'] and observation.get('expectedVersion') == version
            and observation.get('mainRevision') == intent['mainCommit'], 'history target/version/revision mismatch')
    for key in ('currentServingVersionVerified', 'writePermissionVerified', 'publishReady',
                'releaseEvidenceAccepted', 'dynamicsAccepted'):
        require(observation.get(key) is False, 'history cannot claim readiness/serving')
    require(intent['createdAt'] <= observation['startedAt'] <= observation['observedAt'] <= outcome['recordedAt']
            and observation['observedAt'] - observation['startedAt'] <= history.MAX_SECONDS,
            'history timing mismatch')
    report, report_raw = candidate.load(report_path, candidate.MAX_REPORT)
    target = {key: int(intent['target'][key]) for key in ('universeId', 'placeId', 'ownerUserId')}
    result = candidate.review_report(report, manifest, target)
    require(result['reportedPlaceVersion'] == version, 'running-player report is not the retained published version')
    # Do not bless evidence that changed while external source checks were running.
    for name, raw in retained.items():
        require(transaction.read_bytes(evidence / name, bounds[name]) == raw, 'retained evidence changed during intake')
    require(transaction.read_bytes(evidence / 'receipt.json', journal.MAX_RECORD) == receipt_raw
            and transaction.read_bytes(evidence / 'upload-response.json', transaction.MAX_RESPONSE) == raw_response
            and transaction.read_bytes(evidence / 'history.json', journal.MAX_RECORD) == raw_history
            and transaction.read_bytes(report_path, candidate.MAX_REPORT) == report_raw, 'intake inputs changed')
    store.validate_remote()
    require(store.read(journal.intent_ref(consent_pin)) == (remote_head, records), 'journal changed during intake')
    return dict(result, status='RELEASE_REPORT_BOUND_ONLY', releaseBindingConsistent=True,
                releaseEvidenceAccepted=False, dynamicsAccepted=False, currentServingVersionVerified=False,
                downloadedBytesVerified=False, reportAuthenticityVerified=False, publishReady=False,
                publishedVersion=version, receiptSha256=receipt_pin, reportSha256=staging.sha(report_raw),
                terminalCommit=remote_head, manifestSha256=intent['manifestSha256'], placeSha256=intent['placeSha256'],
                warning='Exact retained upload/history/journal and self-reported version are consistent only. '
                        'Not signed Roblox execution, current serving or downloaded-byte proof; '
                        'first-slice success never accepts remaining dynamics/device/feel gates.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--receipt-sha256', required=True)
    parser.add_argument('--consent-sha256', required=True)
    args = parser.parse_args()
    try:
        result = bind(args.report, args.evidence, args.receipt_sha256, args.consent_sha256)
    except Exception:
        print(json.dumps({'status': 'INVALID_OR_UNVERIFIABLE', 'releaseEvidenceAccepted': False,
                          'dynamicsAccepted': False}))
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result['firstSliceReportedPass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
