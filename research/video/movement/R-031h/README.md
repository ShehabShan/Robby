# R-031h — slide/chaining evidence
Source: owner's re-upload `movement.mp4`, bot `e8a8acc8-77f2-40c7-8956-1080ffd63248`, 2026-11-04. [Source artifact](artifact://thread/e8a8acc8-77f2-40c7-8956-1080ffd63248/movement.mp4).
SHA256 `d71c24b6dab93c7ed138a8b44e355c7e8228f77438fd001350bb83af5d4cd541`; 79,162,802 bytes, 1920×1080, 60 fps, 7,561 frames. Video duration 126.016667 s; container/audio may end later. Raw video is not committed.

All nine JPEG sheets were visually reviewed. `manifest.json` records zero-based frame indices, original-pixel crop rectangles, rendered widths and reviewed JPEG hashes. `frame-times.csv` checks the selected indices against ffprobe presentation timestamps after subtracting the first-frame PTS (0.033333 s). Crops support pose inspection; full-frame sheets retain camera/terrain context. Frames are in row-major order; labels use first-frame-relative recording seconds, not input/simulation time.

| Sheet | Purpose |
|---|---|
| ship-context.jpg | Cut into ship scene and overview through end of recording |
| slide-coarse.jpg | Deck low posture through raised/streaked stair transition |
| approach-pose.jpg | Running vs low posture on the deck |
| low-pose-onset.jpg | Broad upright-to-low transition bracket |
| low-pose-exit.jpg | Last low posture and first raised body |
| stair-transition.jpg | First black/white streaks, consecutive container frames |
| streak-exit.jpg | Dense streak-cluster breakup, residual lines and upright continuation |
| occlusion-context.jpg | Wooden geometry hides avatar between sequences |
| second-low-to-rise.jpg | Low posture then the upward traversal studied in R-031f |

Rebuild without modifying originals:
```sh
uv run research/video/movement/R-031h/reproduce.py /path/to/movement.mp4 /tmp/r031h-rebuilt
```
Pinned OpenCV/Pillow versions are embedded. Rebuild verified byte-identical for all nine originals in S153 recovery; other decoder/encoder/platform versions may differ. `adjacent-difference.csv` is reproduced with the sheets: mean absolute per-channel pixel difference in a fixed character/environment crop, not tracked velocity. Paired frames recur, so a 60 fps container does not give 60 independent observations per second or prove simulation FPS. `event-intervals.json` stores reviewed cue brackets and interval arithmetic. One-frame event brackets describe the encoded images only, not 16.7 ms input precision.

## Final recovery audit (2026-11-04, bot 8a135aeb)
The stopped bot's three saved research commits were adopted and merged before this audit. All nine committed sheets were independently re-viewed and their JPEG hashes matched; `python3 research/video/movement/R-031h/verify.py` checks 77 timestamp rows, seven cue brackets, four interval calculations and 78 difference rows. Three temporary damaged copies (JPEG, PTS, interval) were rejected; originals stayed intact. [Machine-readable receipt](recovery-check.json).

Visual correction: n7423–7424 still contain faint residual white line(s). The 0.250–0.284 s value now means **prominent multi-streak-cluster envelope**, not disappearance of every streak/particle. Frame numbers and arithmetic are unchanged; `streak_cluster_end` names the corrected cue.

The raw source GET returned404 here and authorized listings for four documented source bots were empty. This does not prove deletion. Original source fingerprint/decoder reproduction above belong to the stopped bot's record; this audit verifies committed evidence and receipt consistency, **not a fresh raw-video decode**. The JPEGs remain usable without that upload; a new decode requires the same-SHA source again. No new input/physics/cancel-window claims result.
