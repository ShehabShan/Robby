# R-031g evidence — S152 recovery, 2026-11-04

Source: owner's **current** re-upload, bot `f63c1a76-299c-4e79-b6ae-48346c7257be`, artifact `movement.mp4`; [source provenance](../README.md). SHA/size/frame count in manifest. Video not committed. No other bot's video used for this study.

- `burst-context.jpg`: 64–69.5 s, afterimages, second character and descent context.
- `air-a.jpg`, `air-b.jpg`: 72–83.5 s, target presence, overlay occlusion and airborne interactions. Not isolated traversal trials.
- `descent-context.jpg`: 83–85.75 s, camera changes and continued body/ground separation after blue burst.
- `burst1-detail.jpg`, `burst1-descent.jpg`: 67.2–69.4 s at 0.1 s spacing; long downward streak then white burst/rings.
- `burst2-onset.jpg`, `burst2-impact.jpg`: 83–84.15 s at 0.05 s spacing; body arc, camera pitch, blue burst and pillars.
- `burst2-tail.jpg`: 84.2–85.3 s at 0.1 s spacing; late ring disappearance and later floor approach.
- `white-onset.jpg`, `ring-onset.jpg`, `blue-onset.jpg`: consecutive recording frames at visible cue boundaries. Frame precision is not physics/input precision.
- `manifest.json`: exact zero-based source indices, timestamps, crop/width, SHA256 of all twelve visually reviewed JPEGs (~4.2 MB).
- `event-intervals.json`: manually annotated last-absent/first-present and last-present/first-absent brackets; derived durations in recording seconds. No input startup, world speed or recovery claims.
- `adjacent-difference.csv`: fixed source crop (600,260,1280,900), mean absolute channel difference 0–255; forest windows have changing consecutive images. Not a motion tracker, simulation FPS measurement or universal duplicate-frame rule.
- Reproduce: `uv run research/video/movement/R-031g/reproduce.py /path/movement.mp4 /tmp/r031g-rebuilt`. Pinned OpenCV/Pillow; source hash, size and frame count guarded; reviewed directory cannot be overwritten. Encoder differences can change JPEG bytes; manifest pins reviewed originals.
- Findings: [air-dash/slam study](../../../notes/R-031g-air-dash-slam.md). These are research screenshots, not game assets.
