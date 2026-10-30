# Mistvale hub kit (T-021b, D-146): builds the hub building/prop kit from primitives and exports
# one FBX + GLB per piece, a manifest.json (tris, size) and optionally a preview render.
# Run: blender -b --factory-startup --python-exit-code 1 -P art/blender/hub_kit.py -- build/art/hub_kit [--preview]
# Units: 1 Blender unit = 1 stud, Z-up, origin at the piece's base centre (front faces -Y).
# Budget: <= 5000 tris per piece (ART §4). Style: ink-wash xianxia, low poly, clean silhouettes (ART §1-2).
# Enemy telegraph red is never used here (ART §1); lantern light uses a warm paper "glow" colour.
import json
import math
import os
import random
import sys

import bmesh
import bpy

BUDGET = 5000
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = next((a for a in ARGS if not a.startswith("--")), "build/art/hub_kit")
PREVIEW = "--preview" in ARGS
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

PALETTE = {
	"stone": "#8C7B68",
	"mist": "#C9CED6",
	"pine": "#3E5B4A",
	"moss": "#5E7A52",
	"wood": "#6B4A32",
	"darkwood": "#3A2A20",
	"bark": "#4A3A2C",
	"roof": "#2F3A44",
	"plaster": "#EDE3CF",
	"ink": "#141A24",
	"bronze": "#7A6A3A",
	"glow": "#F2D59A",
}
MATS = {}
PARTS = []


def rgba(h):
	h = h.lstrip("#")
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], 1.0)


def mat(name):
	if name not in MATS:
		m = bpy.data.materials.new(name)
		m.use_nodes = True
		col = rgba(PALETTE[name])
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = col
		bsdf.inputs["Roughness"].default_value = 0.85
		if name == "glow":
			bsdf.inputs["Emission Color"].default_value = col
			bsdf.inputs["Emission Strength"].default_value = 3.0
		m.diffuse_color = col
		MATS[name] = m
	return MATS[name]


def _keep(obj, m):
	obj.data.materials.append(mat(m))
	PARTS.append(obj)
	return obj


def box(m, loc, size, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
	obj = bpy.context.object
	obj.scale = size
	return _keep(obj, m)


def cyl(m, loc, r, depth, verts=8, r2=None, rot=(0, 0, 0)):
	if r2 is None:
		bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
	else:
		bpy.ops.mesh.primitive_cone_add(
			vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot
		)
	return _keep(bpy.context.object, m)


def sphere(m, loc, r, scale=(1, 1, 1), seg=12, rings=6):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
	obj = bpy.context.object
	obj.scale = scale
	return _keep(obj, m)


def frustum(m, cx, cy, z0, w0, d0, z1, w1, d1):
	"""Rectangular frustum (w1/d1 small = hip-roof ridge)."""
	corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
	verts = [(cx + sx * w0 / 2, cy + sy * d0 / 2, z0) for sx, sy in corners]
	verts += [(cx + sx * w1 / 2, cy + sy * d1 / 2, z1) for sx, sy in corners]
	faces = [(3, 2, 1, 0), (4, 5, 6, 7)] + [(i, (i + 1) % 4, (i + 1) % 4 + 4, i + 4) for i in range(4)]
	me = bpy.data.meshes.new("part")
	me.from_pydata(verts, [], faces)
	me.update()
	obj = bpy.data.objects.new("part", me)
	bpy.context.collection.objects.link(obj)
	return _keep(obj, m)


def roof(cx, cy, z, w, d, skirt, cap, over=1.5, tips=True):
	"""Tiled roof: fascia + flared eave skirt + optional steep hip cap with ridge, upturned corner tips."""
	ew, ed = w + 2 * over, d + 2 * over
	box("darkwood", (cx, cy, z + 0.15), (ew, ed, 0.3))
	frustum("roof", cx, cy, z + 0.3, ew, ed, z + 0.3 + skirt, w * 0.9, d * 0.9)
	top = z + 0.3 + skirt
	if cap > 0:
		ridge = max(w - d, 0) * 0.5 + w * 0.15
		frustum("roof", cx, cy, top, w * 0.9, d * 0.9, top + cap, ridge, 0.3)
		box("ink", (cx, cy, top + cap + 0.15), (ridge + 0.6, 0.45, 0.35))
	if tips:
		for sx in (-1, 1):
			for sy in (-1, 1):
				cyl(
					"roof",
					(cx + sx * (ew / 2 - 0.2), cy + sy * (ed / 2 - 0.2), z + 0.75),
					0.3,
					1.3,
					verts=4,
					r2=0.03,
					rot=(-sy * 0.75, sx * 0.75, 0),
				)


def lattice(x, y, z, w, h):
	"""Dark window panel with a wooden lattice on a -Y facing wall at y."""
	box("ink", (x, y - 0.1, z), (w, 0.3, h))
	for i in (-1, 1):
		box("wood", (x + i * w / 4, y - 0.28, z), (0.15, 0.1, h))
	box("wood", (x, y - 0.28, z), (w, 0.1, 0.15))
	box("darkwood", (x, y - 0.25, z - h / 2 - 0.1), (w + 0.4, 0.4, 0.2))


def walls(w, d, z0, h, posts):
	box("plaster", (0, 0, z0 + h / 2), (w, d, h))
	for x in posts:
		for y in (-d / 2, d / 2):
			box("darkwood", (x, y, z0 + h / 2), (0.8, 0.8, h))
	for y in (-d / 2 + 2.5, d / 2 - 2.5):
		for x in (-w / 2, w / 2):
			box("darkwood", (x, y, z0 + h / 2), (0.8, 0.8, h))
	box("darkwood", (0, 0, z0 + h - 0.4), (w + 0.6, d + 0.6, 0.8))


# ---------------------------------------------------------------- pieces


def house_a():
	box("stone", (0, 0, 0.5), (16, 12, 1))
	walls(14, 10, 1, 8, (-7, -2.5, 2.5, 7))
	box("ink", (0, -5.1, 3.6), (3, 0.3, 5.2))
	box("darkwood", (0, -5.3, 6.3), (3.8, 0.4, 0.4))
	for x in (-4.75, 4.75):
		lattice(x, -5, 5.4, 2.4, 2)
	box("stone", (0, -6.6, 0.25), (4, 1.2, 0.5))
	roof(0, 0, 9, 14, 10, 1.6, 3.6, over=1.6)


def house_b():
	box("stone", (0, 0, 0.6), (20, 14, 1.2))
	walls(18, 12, 1.2, 8, (-9, -4.5, 4.5, 9))
	box("ink", (0, -6.1, 3.9), (3.6, 0.3, 5.4))
	box("darkwood", (0, -6.3, 6.7), (4.4, 0.4, 0.4))
	for x in (-6.75, -2.6, 2.6, 6.75):
		if abs(x) > 3:
			lattice(x, -6, 5.6, 2.6, 2.2)
	box("stone", (0, -7.6, 0.3), (5, 1.2, 0.6))
	roof(0, 0, 9.2, 18, 12, 1.4, 0, over=1.6)
	walls(13, 8, 10.9, 6, (-6.5, 0, 6.5))
	for x in (-3.25, 3.25):
		lattice(x, -4, 13.8, 2.4, 2)
	roof(0, 0, 16.9, 13, 8, 1.4, 3.4, over=1.6)


def gate():
	for x in (-6, 6):
		box("stone", (x, 0, 0.6), (2.2, 2.2, 1.2))
		cyl("darkwood", (x, 0, 7.2), 0.6, 12, verts=8)
		box("stone", (x, 0, 1.6), (1.6, 1.6, 0.8))
	box("darkwood", (0, 0, 10.4), (15, 0.9, 0.9))
	box("darkwood", (0, 0, 12.6), (16.4, 1.1, 1.0))
	for x in (-2.6, 2.6):
		box("darkwood", (x, 0, 11.5), (0.5, 0.7, 1.4))
	box("plaster", (0, -0.45, 11.5), (4.2, 0.25, 1.5))
	box("ink", (0, -0.6, 11.5), (3.6, 0.1, 1.0))
	roof(0, 0, 13.1, 15, 1.6, 0.6, 1.4, over=1.0)


def rest_spot():
	cyl("stone", (0, 0, 0.3), 6, 0.6, verts=16)
	cyl("mist", (0, 0, 0.85), 4.6, 0.5, verts=16)
	cyl("stone", (0, 0, 1.3), 1.5, 0.4, verts=12)
	cyl("stone", (0, 0, 1.9), 0.6, 0.8, verts=8, r2=0.9)
	sphere("glow", (0, 0, 3.0), 0.7)
	for i in range(6):
		a = i * math.pi / 3
		cyl(
			"plaster",
			(1.7 * math.cos(a), 1.7 * math.sin(a), 1.75),
			0.55,
			1.1,
			verts=4,
			r2=0.02,
			rot=(-math.sin(a) * 0.55, math.cos(a) * 0.55, a),
		)
	for i in range(4):
		a = math.pi / 4 + i * math.pi / 2
		x, y = 5.2 * math.cos(a), 5.2 * math.sin(a)
		box("stone", (x, y, 1.6), (0.6, 0.6, 2.0))
		box("glow", (x, y, 2.9), (0.7, 0.7, 0.6))
		frustum("roof", x, y, 3.2, 1.3, 1.3, 3.7, 0.1, 0.1)


def crucible_shrine():
	box("stone", (0, 0, 0.4), (16, 16, 0.8))
	box("stone", (0, 0, 1.1), (13, 13, 0.6))
	box("mist", (0, 0, 1.6), (11, 11, 0.4))
	box("stone", (0, -8.6, 0.2), (4, 1.2, 0.4))
	for sx in (-1, 1):
		for sy in (-1, 1):
			cyl("darkwood", (sx * 4.5, sy * 4.5, 5.8), 0.45, 8, verts=8)
	box("darkwood", (0, 0, 10.2), (10, 10, 0.8))
	roof(0, 0, 10.6, 10, 10, 1.2, 3.4, over=1.6)
	sphere("bronze", (0, 0, 15.9), 0.45)
	box("stone", (0, 0, 2.4), (4, 4, 1.2))
	for i in range(3):
		a = i * 2 * math.pi / 3
		cyl("bronze", (0.9 * math.cos(a), 0.9 * math.sin(a), 3.4), 0.2, 1.0, verts=6)
	sphere("bronze", (0, 0, 4.4), 1.5, scale=(1, 1, 0.7), seg=16, rings=8)
	cyl("bronze", (0, 0, 5.3), 1.35, 0.3, verts=16)
	cyl("glow", (0, 0, 5.42), 1.1, 0.1, verts=16)
	for sx in (-1, 1):
		box("bronze", (sx * 1.3, 0, 5.8), (0.2, 0.7, 0.8))


def fence_segment():
	for x in (-4, 4):
		box("wood", (x, 0, 2), (0.6, 0.6, 4))
		frustum("darkwood", x, 0, 4, 0.8, 0.8, 4.5, 0.1, 0.1)
	for z in (1.4, 3.2):
		box("wood", (0, 0, z), (8, 0.3, 0.4))


def fence_post():
	box("wood", (0, 0, 2), (0.6, 0.6, 4))
	frustum("darkwood", 0, 0, 4, 0.8, 0.8, 4.5, 0.1, 0.1)


def stone_lantern():
	box("stone", (0, 0, 0.25), (1.6, 1.6, 0.5))
	cyl("stone", (0, 0, 1.6), 0.35, 2.2, verts=8)
	box("stone", (0, 0, 2.85), (1.4, 1.4, 0.3))
	box("glow", (0, 0, 3.45), (0.8, 0.8, 0.9))
	for sx in (-1, 1):
		for sy in (-1, 1):
			box("stone", (sx * 0.55, sy * 0.55, 3.45), (0.2, 0.2, 0.9))
	frustum("stone", 0, 0, 3.9, 1.9, 1.9, 4.6, 0.25, 0.25)
	sphere("stone", (0, 0, 4.8), 0.22, seg=8, rings=4)


def pine(seed, h):
	rnd = random.Random(seed)
	k = h / 14
	cyl("bark", (0, 0, h * 0.2), 0.55 * k, h * 0.4, verts=6, r2=0.3 * k)
	for i in range(4):
		r = (3.4 - 0.75 * i) * k
		x, y = rnd.uniform(-0.25, 0.25) * k, rnd.uniform(-0.25, 0.25) * k
		cyl("pine", (x, y, h * (0.37 + 0.17 * i)), r, h * 0.28, verts=8, r2=r * 0.12, rot=(0, 0, rnd.uniform(0, 6.3)))


def rock(seed, scale):
	rnd = random.Random(seed)
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=(0, 0, scale[2] * 0.55))
	obj = bpy.context.object
	for v in obj.data.vertices:
		v.co *= 0.82 + rnd.random() * 0.36
	obj.scale = scale
	_keep(obj, "stone")
	sphere("moss", (0, 0, scale[2] * 1.3), 1, scale=(scale[0] * 0.7, scale[1] * 0.7, scale[2] * 0.25), seg=8, rings=4)


PIECES = [
	("HubHouseSmall", house_a),
	("HubHouseTall", house_b),
	("HubGate", gate),
	("RestSpot", rest_spot),
	("CrucibleShrine", crucible_shrine),
	("FenceSegment", fence_segment),
	("FencePost", fence_post),
	("StoneLantern", stone_lantern),
	("PineA", lambda: pine(1, 14)),
	("PineB", lambda: pine(2, 18)),
	("PineC", lambda: pine(3, 11)),
	("RockA", lambda: rock(11, (2.4, 1.8, 1.4))),
	("RockB", lambda: rock(12, (4.0, 3.0, 2.2))),
	("RockC", lambda: rock(13, (1.4, 1.2, 1.0))),
]


def finish(name):
	bpy.ops.object.select_all(action="DESELECT")
	for o in PARTS:
		o.select_set(True)
	bpy.context.view_layer.objects.active = PARTS[0]
	bpy.ops.object.join()
	obj = bpy.context.object
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	obj.name = name
	obj.data.name = name
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(obj.data)
	bm.free()
	PARTS.clear()
	return obj


def export(obj):
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	base = os.path.join(OUT, obj.name)
	bpy.ops.export_scene.fbx(
		filepath=base + ".fbx", use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE"
	)
	bpy.ops.export_scene.gltf(filepath=base + ".glb", export_format="GLB", use_selection=True)


def preview(objs):
	"""Contact sheet: buildings in the back row, props in front; Cycles CPU (works headless)."""
	rows = [objs[:5], objs[5:]]
	widths = []
	for r, row in enumerate(rows):
		total = sum(o.dimensions.x for o in row) + 4 * (len(row) - 1)
		x = -total / 2
		for o in row:
			o.location = (x + o.dimensions.x / 2, -r * 26, 0)
			x += o.dimensions.x + 4
		widths.append(total)
	bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
	bpy.context.object.data.materials.append(mat("mist"))
	cam_data = bpy.data.cameras.new("Cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = max(widths) * 1.08
	cam = bpy.data.objects.new("Cam", cam_data)
	bpy.context.collection.objects.link(cam)
	pitch = math.radians(62)
	target = (0, -13, 6)
	cam.location = (target[0], target[1] - 200 * math.sin(pitch), target[2] + 200 * math.cos(pitch))
	cam.rotation_euler = (pitch, 0, 0)
	cam_data.clip_end = 1000
	scene = bpy.context.scene
	scene.camera = cam
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 3.5
	sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(-35))
	bpy.context.collection.objects.link(sun)
	world = bpy.data.worlds.new("World")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs[0].default_value = rgba("#C9CED6")
	world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
	scene.world = world
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 24
	scene.render.resolution_x, scene.render.resolution_y = 1600, 800
	scene.render.filepath = os.path.join(OUT, "preview.png")
	bpy.ops.render.render(write_still=True)


manifest, built, over = {}, [], []
for name, build in PIECES:
	build()
	obj = finish(name)
	tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
	size = [round(v, 2) for v in obj.dimensions]
	manifest[name] = {"tris": tris, "size_studs": size, "materials": [m.name for m in obj.data.materials]}
	export(obj)
	built.append(obj)
	if tris > BUDGET:
		over.append(name)
	print(f"HUBKIT: {name} tris={tris} size={size}")
with open(os.path.join(OUT, "manifest.json"), "w") as f:
	json.dump({"budget_tris": BUDGET, "units": "1 BU = 1 stud, Z-up, base-centre origin", "pieces": manifest}, f, indent=1)
if PREVIEW:
	preview(built)
	print("HUBKIT: preview.png written")
if over:
	print(f"HUBKIT: FAIL over budget: {over}")
	sys.exit(1)
print(f"HUBKIT: OK {len(built)} pieces, max tris {max(m['tris'] for m in manifest.values())} <= {BUDGET}")