# What PromptQL can generate for Robby (probed S114, 2026-11-02)

Gemini calls go through `run_http(integration="__gemini-web-search", ...)` in the **program runtime**. The VM route dropped image responses ("incomplete chunked read"). Probe: `GET /v1beta/models` returned 60 models. Only images were actually tested.

| Asset type | How | Status |
|---|---|---|
| Images (icons, VFX textures, concept art) | `gemini-3-pro-image` (best), `gemini-3.1-flash-image`, `gemini-3.1-flash-lite-image`, `gemini-2.5-flash-image` | **Tested, in use** (5b). Returns JPEG, so convert to PNG. See `gemini_image.py`. |
| Surface textures (albedo, tileable) | Same Gemini image models ("seamless tileable texture, flat lighting"). Normal/roughness maps derived in the VM (Pillow/numpy). | Likely to work; untested |
| Music / short clips (BGM, stingers) | `lyria-3.5`, `lyria-3-pro-preview`, `lyria-3-clip-preview` | Listed; untested |
| Voice lines / narration (TTS) | `gemini-3.8-flash-tts`, `gemini-3.8-flash-lite-tts`, `gemini-2.5-pro-preview-tts` | Listed; untested |
| Live / realtime audio | `*-live*`, `*native-audio*`, `lyria-realtime-exp` (bidiGenerateContent, WebSocket) | Probably not usable via `run_http` |
| 3D models (.glb) | No text-to-3D model on this key. The VM can build models with code (Blender headless or trimesh): fine for simple or low-poly props, not detailed creatures. | AI 3D not available; code-built possible, untested. Keep creatures on the owner's current 3D tool. |
| Animation | No AI animation model. Animations can be written as code (Roblox KeyframeSequence/TweenService, or Blender keyframes in the VM) for simple moves like idle bob, spin, slash arc. | Code-built possible; untested |
| Video | No Veo on this key. PromptQL's Higgsfield integration (image/video/audio) would need connecting; not checked. | Not available on the built-in key |

Next probes, when there is budget (about 1–2 OLU each): one Lyria combat stinger, one TTS line, one tileable texture.
