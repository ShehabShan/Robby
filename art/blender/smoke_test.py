# Headless Blender smoke test: builds a small low-poly "gu bug" from primitives and exports FBX + GLB + OBJ.
# Run: blender -b --factory-startup -P art/blender/smoke_test.py -- build/art
import os
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build/art"
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0)
body = bpy.context.object
body.scale = (1.0, 1.6, 0.7)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.5, location=(0, 1.7, 0.1))
for side in (-1, 1):
	for i in range(3):
		bpy.ops.mesh.primitive_cylinder_add(
			vertices=6, radius=0.06, depth=1.2, location=(side * 1.0, -0.6 + i * 0.6, -0.2), rotation=(0, 1.2 * side, 0)
		)

mat = bpy.data.materials.new("GuJade")
mat.diffuse_color = (0.2, 0.8, 0.5, 1.0)
for obj in bpy.context.scene.objects:
	obj.data.materials.append(mat)
	obj.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
body.name = "GuBug"

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, "GuBug.fbx"), use_selection=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "GuBug.glb"), export_format="GLB")
bpy.ops.wm.obj_export(filepath=os.path.join(out, "GuBug.obj"))
sizes = {f: os.path.getsize(os.path.join(out, f)) for f in ("GuBug.fbx", "GuBug.glb", "GuBug.obj")}
print(f"SMOKE: OK tris={tris} files={sizes}")