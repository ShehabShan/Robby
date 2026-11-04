# R-031e evidence — S150, 2026-11-04

Selected audit evidence, not the whole video. [Findings and per-claim corrections](../../../notes/R-031e-movement-mechanics.md). The original remains outside git; see [parent provenance](../README.md).

- `manifest.json`: input fingerprint, exact zero-based frame indices, n/60 timestamps and sheet SHA256s. Six inspected sheets, ~2.5 MB total.
- `identity-proof.jpg`: source-resolution crops from frame1200 (HUD x0..330,y810..1080), frame4410 (overlay x650..1250,y170..640), frame7290 (title x0..730,y0..110; enlarged 1.4×). Crops are labeled; no inferred key presses.
- `air-context.jpg`: 73–84.5 s at 2 samples/s; `air-end.jpg`: 82–85.833 s at 6 samples/s. Context, not proof of invulnerability/charges or a target-free slam.
- `ship.jpg`: 122–125.867 s, nominal 8 samples/s rounded to nearest source frame. `cuts.jpg` and `ship-cut.jpg`: cut-boundary brackets, not exact edit frames.
- `source-checks.json`: small direct-fetch receipt/excerpts, including blocked Deepwoken request. Search summaries are not independent verification. Full third-party pages are intentionally not stored.

Reproduce a frame: `ffmpeg -i movement.mp4 -vf "select='eq(n,1200)'" -frames:v 1 frame.png`. For a sheet select the manifest frame indices with summed `eq(n,...)`, use `-fps_mode vfr`, scale each frame, and label with its original frame index / 60. Do not label an fps-resampled output with a new PTS and assume it is the exact source timestamp. Sampling interval does not establish event duration; camera motion/occlusion prevents exact world-space inference.

This directory intentionally force-tracks only the six small JPG proof sheets; other video frames and the MP4 remain ignored. S149's R-031f detailed strafe/jump log is independent and not edited by this audit.
