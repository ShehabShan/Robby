"""Validate committed R-031h receipts, not raw-video decoding or gameplay mechanics.
Run: python3 research/video/movement/R-031h/verify.py [evidence-directory]
"""
import csv
import hashlib
import json
import math
import sys
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def near(actual, expected, label, tolerance=0.0000011):
    require(math.isfinite(float(actual)) and abs(float(actual) - expected) <= tolerance, label)


def verify(root):
    manifest = json.loads((root / 'manifest.json').read_text())
    fps = manifest['fps']
    require(fps == 60 and manifest['source_frames'] == 7561, 'source metadata')
    require(manifest['source_bytes'] == 79162802, 'source size metadata')
    selected = set()
    require(len(manifest['sheets']) == 9, 'sheet count')
    for name, sheet in manifest['sheets'].items():
        raw = (root / (name + '.jpg')).read_bytes()
        require(raw.startswith(b'\xff\xd8\xff'), f'{name}: JPEG signature')
        require(hashlib.sha256(raw).hexdigest() == sheet['sha256'], f'{name}: hash')
        frames = sheet['frames']
        require(frames == sorted(set(frames)), f'{name}: frame order')
        require(all(type(n) is int and 0 <= n < manifest['source_frames'] for n in frames), f'{name}: frame bounds')
        selected.update(frames)
    rows = list(csv.DictReader((root / 'frame-times.csv').open()))
    require(len(rows) == len(selected) == 77, 'PTS row count')
    require([int(r['frame']) for r in rows] == sorted(selected), 'PTS coverage/order')
    offset = manifest['raw_pts_first_frame_seconds']
    near(offset, 0.033333, 'PTS offset')
    for row in rows:
        t = int(row['frame']) / fps
        near(row['sheet_label_seconds'], t, 'sheet label')
        near(row['first_frame_relative_seconds'], t, 'relative PTS')
        near(row['raw_pts_seconds'], t + offset, 'raw PTS')
    cues = json.loads((root / 'event-intervals.json').read_text())
    require(len(cues['events']) == 7 and len(cues['intervals']) == 4, 'cue counts')
    for name, event in cues['events'].items():
        lo, hi = event['frames']
        require(lo <= hi and lo in selected and hi in selected, name + ': covered endpoints')
        for n, t in zip(event['frames'], event['first_frame_relative_seconds'], strict=True):
            near(t, n / fps, name + ': cue time')
    for name, interval in cues['intervals'].items():
        a = cues['events'][interval['from']]['frames']
        b = cues['events'][interval['to']]['frames']
        expected = [(b[0] - a[1]) / fps, (b[1] - a[0]) / fps]
        for value, wanted in zip(interval['seconds_bounds'], expected, strict=True):
            near(value, wanted, name + ': interval arithmetic', 1e-12)
    diffs = list(csv.DictReader((root / 'adjacent-difference.csv').open()))
    expected_frames = list(range(7375, 7429)) + list(range(7477, 7501))
    require([int(r['frame']) for r in diffs] == expected_frames, 'difference coverage/order')
    for row in diffs:
        n = int(row['frame'])
        require(int(row['previous_frame']) == n - 1, 'difference adjacency')
        near(row['recording_seconds'], n / fps, 'difference timestamp')
        value = float(row['crop_mean_abs_channel_difference_0_255'])
        require(math.isfinite(value) and 0 <= value <= 255, 'difference value range')
    return {'result': 'PASS', 'jpeg_hashes': 9, 'timestamp_rows': len(rows),
            'event_brackets': 7, 'interval_calculations': 4, 'difference_rows': len(diffs),
            'scope': 'Committed receipt consistency only; no raw decode, input or physics validation'}


if __name__ == '__main__':
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    print(json.dumps(verify(root), indent=2))
