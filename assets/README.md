# assets/

- `source/`: **owner-provided** 3D models, textures and audio (FBX/GLB/OBJ/PNG/OGG…). Never edit or delete these. Convert copies instead.
  - Name files `<category>-<name>.<ext>`, e.g. `creature-moonlight-gu.fbx`, and add one line per file to `source/INDEX.md` (what it is, where it came from, license).
  - Keep each file under 50 MB (GitHub's limit is 100 MB). Larger files need Git LFS; decide that in P-003.
- Generated assets are **not** committed. They are rebuilt from scripts in `art/blender/` into `build/art/` (gitignored).
- Upload to Roblox happens via Open Cloud (route decided in R-015 / P-003). It needs the owner's API key.