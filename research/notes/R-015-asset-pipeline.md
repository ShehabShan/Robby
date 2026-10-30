# R-015 — Headless asset pipeline feasibility (S4, 2026-10-30)

Goal: for each asset type, find a route that works without Roblox Studio, and say what quality, cost and owner involvement it needs.
[n] marks a source. Model-memory items are labelled "(unverified)".

## 1. Findings
### Upload (Open Cloud Assets API)
- `POST apis.roblox.com/assets/v1/assets` creates Model, Decal/Image, Audio, Animation, Mesh and Video assets. [1][2][3]
- Formats: `.fbx/.gltf/.glb/.rbxm/.rbxmx` (models), `.rbxm/.rbxmx` (animations), `.png/.jpeg/.bmp/.tga` (images), `.mp3/.ogg/.wav/.flac` (audio). Max 20 MB. [1][2]
- Auth: API key (`x-api-key`) or OAuth with `asset:read`/`asset:write`. [1][3]
- Audio: ≤ 7 min; 100 uploads/month for ID-verified accounts, 10 otherwise. [1][4][5]

### Roblox import limits
- 20,000 triangles per mesh; skinned meshes allow up to 4 bone influences per vertex. [6][7][8]
- Textures/SurfaceAppearance: 1024×1024 is the common target (2048 for some assets); 4K is accepted but may be downsampled. [7][9]

### Blender headless (known from S3)
- Blender 4.2 LTS runs in the VM; `art/blender/smoke_test.py` builds a mesh and exports FBX/GLB/OBJ.

### Animations
- Animations can be uploaded via Open Cloud as `.rbxm/.rbxmx`. [2][1]
- `anim2rbx` (Rust CLI) converts an FBX animation to a KeyframeSequence `.rbxmx` without Studio. [10]
- FBX rigs often break on bone mapping/constraints; export with correct axes. [11][12][13]
- The official Roblox Blender plugin has no animation upload. [14]

### VFX, terrain, UI
- VFX = ParticleEmitter, Beam and Trail instances whose properties are set in code; their textures are uploaded images. [15]
- Terrain: `Terrain:WriteVoxels` on a 4-stud grid gives smooth procedural terrain; generate in chunks; voxel data can be serialised to a buffer. [16][17][18][19]
- UI can be built in code (Frames, gradients, strokes) with AI-made icons as images. (unverified)

### AI generation
- Roblox Cube 3D / GenerationService (beta) generates meshes/models in-experience with triangle and bounding-box limits. [20][21][22]
- Tripo and Meshy offer REST APIs; licences differ by tool and plan. [23][24]
- AI images: many tools give commercial rights on paid plans; tileable PBR textures possible; all uploads are moderated; the creator is responsible for IP. [25][26][27]

### Creator Store
- Creator Store assets are licensed for use in Roblox experiences under the Terms of Use. [28][29]
- Free models may contain stolen content and can be removed; free assets are shared for AI training. [30][31]

## 2. Route table (AC)

| Asset type | Headless route | Quality | Cost | Owner involvement |
|---|---|---|---|---|
| Environment meshes (rocks, huts, props) | Blender Python scripts → FBX/GLB → Open Cloud Model upload | Low–mid, stylised | OLU only | Open Cloud API key (once) |
| Hero meshes (characters, creatures, bosses) | Owner models in `assets/source/`, or AI 3D (Tripo/Meshy, paid licence) cleaned in Blender, or a hired artist | Mid–high | Tool subscription or artist fee | Budget decision; provide/approve models |
| Textures & images | Blender procedural bakes or AI images → PNG ≤ 1024 → Image upload | Mid | Low (AI plan if needed) | API key; check AI tool licence |
| Animations | Blender scripted keyframes on a rig → FBX → `anim2rbx` → `.rbxmx` → Animation upload | Low–mid scripted; high needs an animator/mocap | OLU, or animator fee | Likely animator budget for combat |
| VFX | Code-defined ParticleEmitter/Beam/Trail in Rojo + uploaded textures | Mid–high | Low | None |
| Audio | Licensed Creator Store audio, or AI audio with commercial licence → Audio upload | Mid | Low | ID-verify the uploading account (100/month) |
| Terrain & maps | `WriteVoxels` generator scripts + Rojo-built parts/models | Mid | OLU only | None |
| UI art | Code-built UI + AI icons as images | Mid–high | Low | None |
| Creator Store assets | Only from verified/official creators, logged in `assets/` index | Varies | Free–paid | None (vet each asset) |

## 3. → Implications for Robby
- Fully headless is feasible. The one required owner step is an Open Cloud API key stored in a PromptQL custom integration.
- Bottlenecks: hero meshes and combat animations. Plan a stylised art direction and likely an artist/animator budget (P-004).
- First T-phase spike: upload one Blender mesh and one `anim2rbx` animation, then play them in a test place.

## 4. Unknowns
- `anim2rbx` with R15 and custom creature rigs.
- How to bake generated terrain into the saved place (runtime generation vs Luau Execution save).
- AI 3D mesh quality and topology; availability and licence of PromptQL's `__higgsfield`.

## 5. Sources
1. create.roblox.com/docs/cloud/guides/usage-assets
2. devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082
3. create.roblox.com/docs/en-us/reference/cloud/assets/v1
4. create.roblox.com/docs/en-us/audio/assets
5. devforum.roblox.com/t/update-changes-to-asset-privacy-for-audio/1715717
6. create.roblox.com/docs/en-us/art/modeling/specifications
7. create.roblox.com/docs/en-us/art/characters/specifications
8. devforum.roblox.com/t/new-unified-smart-mesh-importer-beta/1583213
9. create.roblox.com/docs/en-us/art/modeling/texture-specifications
10. github.com/jiwonz/anim2rbx
11. devforum.roblox.com/t/how-can-i-animate-skinned-mesh-r15-in-blender-and-import-into-studio/2962873
12. devforum.roblox.com/t/fbx-animation-file-fails-to-load-any-keyframes/4032197
13. nilo.io/articles/export-blender-animation-roblox-studio
14. github.com/Roblox/roblox-blender-plugin/issues/92
15. create.roblox.com/docs/en-us/projects/assets
16. picoo.io/how-to-make/roblox-terrain-generation
17. create.roblox.com/docs/reference/engine/classes/Terrain
18. devforum.roblox.com/t/how-to-use-terrainwritevoxels/856752
19. devforum.roblox.com/t/savingloading-terrain-inside-data-store/3391849
20. create.roblox.com/docs/reference/engine/classes/GenerationService
21. create.roblox.com/docs/en-us/parts/model-generation
22. devforum.roblox.com/t/beta-cube-3d-model-updates-better-quality-and-bounding-box-control/3828156
23. meshy.ai/api
24. devforum.roblox.com/t/beta-cube-3d-generation-tools-and-apis-for-creators/3558947
25. create.roblox.com/docs/en-us/generative-AI
26. devforum.roblox.com/t/protecting-intellectual-property-when-using-generative-ai/2881851
27. gamedevgenie.com ; clicklab.art
28. en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms
29. github.com/Roblox/creator-docs (production/creator-store.md)
30. devforum.roblox.com/t/can-i-use-free-models-in-ugc-items/3375358
31. create.roblox.com/docs/en-us/ai-data-sharing