# R-031f evidence — S151, 2026-11-04

Primary source: [provenance](../README.md), same SHA256 in `manifest.json`. Re-upload verified on bot `1c9edfbe-1d31-4e33-83c5-57f798c06e22`, artifact `movement.mp4`. Full video stays outside git. Images are research evidence, not game assets.

- `strafe-b.jpg`, `strafe-detail.jpg`, `strafe-change.jpg`: controlled-facing lateral steps, 44.9–48.2 s; pose change around 46.2–46.4 s. Camera moves too; not a motion-capture or input trace.
- `strafe-a.jpg`, `jump-context.jpg`: exclusion evidence. Old 22 s strafe and 24 s jump labels are not clean isolated tests.
- `ship-jump-context.jpg`: camera/environment context, 124.2–126.0 s, including beam occlusion and upper deck.
- `jump-takeoff.jpg`, `jump-arrival.jpg`, `jump-tail.jpg`: 30-sample/s detail; lower-deck launch, edge crossing, airborne-looking continuation.
- `jump-onset-60.jpg`, `jump-ledge-60.jpg`: consecutive container frames at important boundaries. Several adjacent pairs repeat; do not claim 60 independent gameplay images/s.
- `manifest.json`: exact zero-based frame indices, recording timestamps, original-pixel crops, tile widths and reviewed JPEG hashes. No retiming. Labels rounded to four decimals, not uncertainty estimates.
- `adjacent-difference.csv`: mean absolute channel difference in fixed original-pixel crop `(600,260,1280,900)`, scale 0–255; **not** player velocity, smoothness score or simulation FPS. Selected ship pairs are nearly identical while intervening transitions differ strongly. At least ~33 ms visual granularity in those samples, with additional event ambiguity.
- Reproduce: `uv run research/video/movement/R-031f/reproduce.py /path/movement.mp4 /tmp/r031f-rebuilt`. Source hash/size/frame-count guarded; output must be outside this evidence folder. JPEG encoder differences may change hashes; manifest hashes identify reviewed originals.
- Findings and limitations: [research note](../../../notes/R-031f-strafe-jump.md). No height ruler, reference camera calibration, held inputs or live Roblox measurements supplied.
