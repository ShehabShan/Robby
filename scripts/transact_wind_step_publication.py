"""One-shot isolated publication. Never run without genuine independently reviewed owner sources.
No retry/resume API. History is not current-serving, downloaded-byte or dynamics proof.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import time
import urllib.error
import urllib.request

import preflight_wind_step_release as gates
import stage_wind_step_published as staging
import wind_step_permission_review as review
import wind_step_intent_journal as journal
import observe_wind_step_publication as history
from test_target import validate_config, validate_remote
from ingest_wind_step_evidence import strict_json

require = staging.require
MAX_RESPONSE = 65536
MAX_SOURCE = 1024 * 1024


def read_bytes(path, maximum):
    with Path(path).open('rb') as stream:
        raw = stream.read(maximum + 1)
    require(0 < len(raw) <= maximum, 'invalid evidence size')
    return raw


def upload(target, place):
    """Single request, no redirects, retries or credential extraction; bounded response."""
    validate_config(target)
    require(type(place) is bytes and 0 < len(place) <= staging.MAX_PLACE, 'invalid upload bytes')
    url = (os.environ['PROMPTQL_PLATFORM_API_URL']
           + '/v1/integration/roblox-open-cloud/apis.roblox.com/universes/v1/'
           + target['universeId'] + '/places/' + target['placeId'] + '/versions?versionType=Published')
    request = urllib.request.Request(url, data=place, method='POST', headers={
        'Authorization': 'Bearer ' + os.environ['PROMPTQL_USER_JWT'],
        'Content-Type': 'application/octet-stream',
        'X-PromptQL-Description': 'Publish exact owner-consented isolated Wind Step test bytes once; never production'})
    try:
        with urllib.request.build_opener(gates.NoRedirect()).open(request, timeout=600) as response:
            status, raw = response.status, response.read(MAX_RESPONSE + 1)
        require(type(status) is int and status == 200 and 0 < len(raw) <= MAX_RESPONSE,
                'publication response uncertain; never retry')
        return raw
    except Exception:
        # Do not leak proxy errors, headers, credentials or arbitrary upstream bodies.
        raise ValueError('publication response uncertain; never retry') from None


def snapshot(inputs, spool):
    """Keep immutable in-memory bytes and a fsynced evidence copy outside build/temp."""
    specs = {'manifest': staging.MAX_MANIFEST, 'place': staging.MAX_PLACE,
             'consent': gates.MAX_CONSENT, 'review': review.MAX_REVIEW, 'source': MAX_SOURCE}
    require(set(inputs) == set(specs), 'unexpected transaction inputs')
    raw = {}
    for name, maximum in specs.items():
        path, pin = inputs[name]
        review.digest(pin)
        raw[name] = read_bytes(path, maximum)
        require(staging.sha(raw[name]) == pin, 'independent evidence pin mismatch')
    spool = Path(spool).resolve()
    require(spool.is_dir(), 'durable spool must already exist')
    require(not spool.is_relative_to(staging.ROOT) and not spool.is_relative_to(Path(tempfile.gettempdir()).resolve()),
            'spool must be outside repository and temporary outputs')
    directory = spool / ('evidence-' + inputs['consent'][1])
    directory.mkdir(mode=0o700)  # no local replay, even after a partial snapshot
    journal.sync_dir(spool)
    for name, data in raw.items():
        journal.write_once(directory / name, data)
    return raw, directory


def transact(inputs, spool, *, owner_sources_reviewed=False, inspect=gates.checkout,
             read_target=gates.read_universe, post=upload, read_page=history.read_history,
             clock=time.time, store=None):
    """Trusted operator supplies independent pins after checking authentic owner sources.

    This acknowledgment is NOT an identity/signature verifier. JSON consistency alone
    never authenticates consent, reviewer or the broker's current permission grant.
    Injected seams are for offline tests, not alternate production authorization paths.
    """
    require(owner_sources_reviewed is True, 'independent genuine owner-source review required')
    started = previous = clock()
    require(type(started) in (int, float) and math.isfinite(started) and started > 0, 'invalid clock')

    def tick(pre_dispatch=True):
        nonlocal previous
        now = clock()
        require(type(now) in (int, float) and math.isfinite(now) and now >= previous, 'clock reversed/invalid')
        if pre_dispatch:
            require(now - started <= gates.MAX_PREFLIGHT, 'stale transaction gates')
        previous = now
        return now

    head = gates.validate_checkout(inspect())
    store = store if store is not None else journal.GitStore(staging.ROOT)
    raw, directory = snapshot(inputs, spool)
    manifest = strict_json(raw['manifest'].decode('utf-8'))
    consent = strict_json(raw['consent'].decode('utf-8'))
    require(type(manifest) is dict, 'manifest must be an object')
    require(manifest.get('sourceRevision') == head, 'staged source revision must equal current main')
    target = manifest.get('target')
    validate_config(target)

    def validate_records(now):
        gates.validate_consent(consent, manifest, inputs['manifest'][1], now)
        review.load_review(directory / 'review', inputs['review'][1], target, now,
                           reviewed_source_pin=inputs['source'][1])

    def validate_files():
        for name, data in raw.items():
            require(read_bytes(inputs[name][0], len(data)) == data
                    and read_bytes(directory / name, len(data)) == data, 'evidence changed during transaction')

    def fresh_gates():
        validate_records(tick())
        require(gates.validate_checkout(inspect()) == head, 'main changed during transaction')
        store.validate_remote()
        validate_files()
        # Validate exact retained snapshot with actual source and enabled-package checks.
        staging.verify(directory / 'manifest', inputs['manifest'][1], directory / 'place')
        tick()
        remote = read_target(target['universeId'])
        validate_remote(target, remote)
        validate_records(tick())
        require(gates.validate_checkout(inspect()) == head, 'main changed during target observation')
        validate_files()
        return hashlib.sha256(json.dumps(remote, sort_keys=True, allow_nan=False).encode()).hexdigest()

    before = fresh_gates()
    intent = dict(schema=1, kind=journal.INTENT_KIND, target=dict(target),
                  consentSha256=inputs['consent'][1], manifestSha256=inputs['manifest'][1],
                  placeSha256=inputs['place'][1], reviewSha256=inputs['review'][1],
                  reviewedSourceSha256=inputs['source'][1], mainCommit=head, createdAt=int(tick()))
    ticket = journal.reserve(intent, store, spool)
    status, version, response_pin, history_pin = 'REJECTED', None, None, None
    observation = None
    dispatched = False
    try:
        after = fresh_gates()  # a reservation is never permission; recheck ALL gates
        journal.write_once(directory / 'pre-dispatch.json', journal.encode({
            'mainCommit': head, 'targetObservationSha256': [before, after],
            'intentSha256': journal.sha(ticket.intent_raw)}))
        observed, records = store.read(ticket.ref)
        require(observed == ticket.head and records == {'intent.json': strict_json(ticket.intent_raw.decode())},
                'reservation changed before dispatch')
        require(gates.validate_checkout(inspect()) == head, 'main changed before dispatch')
        validate_files()
        # No external operation between these last time/record checks and dispatch.
        validate_records(tick())
        dispatched = True
        status = 'UNCERTAIN'
        response = post(dict(target), raw['place'])
        tick(False)
        require(type(response) is bytes and 0 < len(response) <= MAX_RESPONSE, 'invalid upload response size')
        response_pin = staging.sha(response)
        parsed = strict_json(response.decode('utf-8'))
        require(type(parsed) is dict and set(parsed) == {'versionNumber'}, 'unexpected upload response')
        expected = history.version_number(parsed['versionNumber'])
        journal.write_once(directory / 'upload-response.json', response)
        observation = history.observe(target, expected, inspect=inspect, read_target=read_target,
                                      read_page=read_page, clock=clock)
        tick(False)
        require(observation['mainRevision'] == head, 'main changed after dispatch')
        validate_files()
        journal.write_once(directory / 'history.json', journal.encode(observation))
        if observation['status'] == 'PUBLICATION_HISTORY_OBSERVED':
            status, version = 'HISTORY_CONFIRMED', expected
            history_pin = staging.sha(journal.encode(observation))
    except Exception:
        # Once POST may have started, every failure is uncertain, NOT retry permission.
        status = 'UNCERTAIN' if dispatched else 'REJECTED'
        version, history_pin = None, None
    outcome = dict(schema=1, kind='WindStep isolated publication outcome',
                   intentSha256=journal.sha(ticket.intent_raw), status=status,
                   recordedAt=max(intent['createdAt'], int(previous)), version=version,
                   responseSha256=response_pin, historySha256=history_pin)
    terminal = journal.finish(ticket, outcome, store)  # failure leaves consent consumed; never retry
    receipt = dict(outcome, terminalCommit=terminal, mainCommit=head, target=dict(target),
                   manifestSha256=inputs['manifest'][1], placeSha256=inputs['place'][1],
                   consentSha256=inputs['consent'][1], reviewSha256=inputs['review'][1],
                   reviewedSourceSha256=inputs['source'][1], dispatched=dispatched,
                   retryAllowed=False, currentServingVersionVerified=False,
                   writePermissionVerified=False, reviewerIdentityVerified=False,
                   publishReady=False, releaseEvidenceAccepted=False, dynamicsAccepted=False)
    journal.write_once(directory / 'receipt.json', journal.encode(receipt))
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('manifest', 'place', 'consent', 'review', 'source'):
        parser.add_argument('--' + name, required=True)
        parser.add_argument('--' + name + '-sha256', required=True)
    parser.add_argument('--spool', required=True)
    parser.add_argument('--execute-reviewed-owner-publication', action='store_true')
    args = parser.parse_args()
    inputs = {name: (getattr(args, name), getattr(args, name + '_sha256'))
              for name in ('manifest', 'place', 'consent', 'review', 'source')}
    try:
        receipt = transact(inputs, args.spool, owner_sources_reviewed=args.execute_reviewed_owner_publication)
        print(json.dumps(receipt, sort_keys=True))
        return 0 if receipt['status'] == 'HISTORY_CONFIRMED' else 1
    except Exception:
        print('BLOCKED OR UNCERTAIN: inspect retained journal/evidence; never retry this consent.')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
