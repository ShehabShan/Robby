# movement video (R-031)
- Owner's own edit (2026-11-03), re-uploaded 2026-11-04: H264/AAC, 1920×1080, 60 fps, container duration 126.058667 s, 79,162,802 bytes.
- SHA256: `d71c24b6dab93c7ed138a8b44e355c7e8228f77438fd001350bb83af5d4cd541` (S150 verified download).
- Source artifact: `movement.mp4` on bot **9bbad4f4-2f3e-474d-99d7-ab94c51acd94**. [Open source](artifact://thread/9bbad4f4-2f3e-474d-99d7-ab94c51acd94/movement.mp4). VM working copy: `/workspace/media/movement.mp4` in that bot, not a shared path.
- Download in an authorized VM: `curl -f "$PROMPTQL_PLATFORM_API_URL/v1/artifacts/threads/9bbad4f4-2f3e-474d-99d7-ab94c51acd94/movement.mp4" -H "Authorization: Bearer $PROMPTQL_USER_JWT" -o /tmp/movement.mp4`; check the fingerprint before analysis. No embedded credential.
- Not in git: the GitHub push proxy rejected the old 79 MB upload (HTTP 413). Earlier artifact on bot ee08ce6b-7f15-4a65-9896-e4a8f2f4194b returned 404 in S148; do not use that as the only pointer.
- Owner: do NOT use the Gemini cut list / edit plan; the owner's edit replaces it.
- [S150 R-031e audit](../../notes/R-031e-movement-mechanics.md) corrects the public-source pass and qualifies earlier log assertions; [committed evidence](R-031e/README.md) survives independently of the upload.
- Detailed R-031f–h research continues in its own lanes. `log.md` contains historical estimates, not calibrated world-space measurements or input telemetry.
