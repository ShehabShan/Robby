"""T-043d1 original faceted frost prototype, not live gameplay.
blender -b --factory-startup --python-exit-code 1 -P art/blender/rime_m1.py -- build/art/rime_m1
1 unit = 1 stud. Blender Z-up, forward +Y; exports convert to Y-up.
Pose data is Roblox XYZ Euler degrees; previews use an approximate R15 mannequin.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / (sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'build/art/rime_m1')
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = json.loads((ROOT / 'art/poses/rime_m1.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.055, .08, .12, 1)
scene.view_settings.view_transform = 'AgX'

def material(name, color, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = .32
    b.inputs['Metallic'].default_value = metal
    return m

ICE = [material('Frost ivory', (.68,.92,1)), material('Glacial cyan', (.10,.48,.65)), material('Deep cut', (.025,.13,.23)), material('Ridge', (.86,.98,1))]
BODY = material('Mannequin slate', (.12,.19,.25))
ARMS = material('Mannequin porcelain', (.55,.65,.69))
GROUND = material('Ground', (.035,.055,.075))

def cube(name, loc, size, mat, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.name=name; o.dimensions=size
    if rotation is not None: o.rotation_euler=rotation.to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    bevel=o.modifiers.new('Small edge', 'BEVEL'); bevel.width=.045; bevel.segments=2
    o.modifiers.new('Normals','WEIGHTED_NORMAL')
    return o

SHAPES={}
manifest={'source':'art/blender/rime_m1.py + art/poses/rime_m1.json','original':True,'units':'studs','forward':'Blender +Y / Roblox -Z','collision':'visual only; CanCollide/CanTouch/CanQuery false when integrated','assets':[]}
# Two offset diamond rings with a rear and front tip: 10 vertices / 16 triangles.
for name,lean,width in [('needle_left',-.045,.27),('needle_right',.045,.27),('needle_pair',0,.32)]:
    verts=[(0,.85,0)]
    for y,w,h,offset in [(.48,width*.48,.09,-lean),(-.18,width*.5,.115,lean)]:
        verts += [(offset+w,y,0),(offset,y,h),(offset-w,y,0),(offset,y,-h)]
    verts += [(lean,-.95,.018)]
    verts = [(x,-y,z) for x,y,z in verts] # +Y forward becomes -Z in Y-up exports
    faces=[]
    for i in range(4):
        j=(i+1)%4
        faces += [(0,1+j,1+i),(1+i,1+j,5+j),(1+i,5+j,5+i),(5+i,5+j,9)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); scene.collection.objects.link(o)
    for m in ICE: mesh.materials.append(m)
    for i,p in enumerate(mesh.polygons): p.material_index=[1,0,2,3][i//4]
    # Correct outward normals deterministically, without smoothing away facets.
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True,export_format='GLB')
    bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,axis_forward='-Z',axis_up='Y',apply_unit_scale=False,add_leaf_bones=False)
    o.select_set(False); SHAPES[name]=o
    manifest['assets'].append({'name':name,'vertices':len(verts),'triangles':len(faces),'size':list(o.dimensions),'pivot':'centre of dart, tip toward forward','files':[name+'.fbx',name+'.glb'],'sha_source':'rebuild from committed source; no external mesh/texture'})

# Geometry gate: closed manifold, positive volume and slender footprint.
import bmesh
for o in SHAPES.values():
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges)
    assert bm.calc_volume(signed=True)>0
    assert len(bm.faces)==16 and o.dimensions.y < 2
    bm.free()

bpy.ops.object.camera_add(location=(3,12,7))
CAM=bpy.context.object; scene.camera=CAM; CAM.data.type='ORTHO'
def aim(target,scale):
    CAM.rotation_euler=(Vector(target)-CAM.location).to_track_quat('-Z','Y').to_euler(); CAM.data.ortho_scale=scale
for loc,power,size in [((2,-4,8),1100,6),((-5,1,5),900,5)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    o=bpy.context.object; o.data.energy=power; o.data.shape='DISK'; o.data.size=size
    o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()

def render(name):
    scene.render.filepath=str(OUT/name); bpy.ops.render.render(write_still=True)

for i,o in enumerate(SHAPES.values()):
    o.location=((i-1)*1.1,0,1)
cube('Display floor',(0,0,-.15),(200,200,.1),GROUND)
aim((0,0,.8),4.3)
render('shards.png')
# Save editable source scene with unjoined individual meshes before mannequin preview.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rime_m1_shapes.blend'))
for o in SHAPES.values(): o.hide_render=True; o.hide_viewport=True

# Roblox Y-up -> Blender Z-up; rotation is Rx*Ry*Rz as CFrame.Angles.
B=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def rot(v):
    return Matrix.Rotation(math.radians(v[0]),3,'X') @ Matrix.Rotation(math.radians(v[1]),3,'Y') @ Matrix.Rotation(math.radians(v[2]),3,'Z')

def proxy_box(name,position,size,r,mat):
    # Convert size axes with absolute value; preserve the joint's orientation.
    return cube(name,B@Vector(position),(size[0],size[2],size[1]),mat,B@r@B.transposed())

I=Matrix.Identity(3)
proxy_box('UpperTorso',(0,3.8,0),(1.55,1.05,.75),I,BODY)
proxy_box('LowerTorso',(0,2.95,0),(1.25,.65,.7),I,BODY)
proxy_box('Head',(0,4.85,0),(.9,.9,.85),I,ARMS)
proxy_box('Face direction',(0,4.9,-.435),(.62,.12,.025),I,BODY)
for side,x in [('Left',-.4),('Right',.4)]:
    proxy_box(side+'UpperLeg',(x,2.2,0),(.6,.95,.65),I,BODY)
    proxy_box(side+'LowerLeg',(x,1.22,0),(.55,.9,.55),I,BODY)
    proxy_box(side+'Foot',(x,.58,-.12),(.6,.35,.85),I,BODY)

DYNAMIC=[]
def pose(angles,clip):
    for o in DYNAMIC: bpy.data.objects.remove(o,do_unlink=True)
    DYNAMIC.clear(); hands={}
    for side,sign in [('Left',-1),('Right',1)]:
        joint=Vector((sign*.9,4.2,0)); r=I.copy()
        for part,length,width in [('UpperArm',.72,.42),('LowerArm',.68,.36),('Hand',.34,.38)]:
            name=side+part; r=r@rot(angles[name])
            center=joint+r@Vector((0,-length/2,0))
            DYNAMIC.append(proxy_box(name,center,(width,length,.42),r,ARMS))
            joint=joint+r@Vector((0,-length,0))
        hands[side]=joint
    sides=['Left'] if clip['name']=='needle_1' else ['Right'] if clip['name']=='needle_2' else ['Left','Right']
    for side in sides:
        # Staged hand-adjacent signature; not a proposed server projectile origin.
        o=SHAPES[clip['shape']].copy(); o.data=o.data.copy(); scene.collection.objects.link(o)
        o.hide_render=False; o.hide_viewport=False; o.location=B@(hands[side]+Vector((0,0,-1.05)))
        o.rotation_euler.z=math.radians(3 if side=='Left' else -3) if len(sides)==2 else 0
        DYNAMIC.append(o)

aim((0,0,2.9),6.7)
for clip in SOURCE['clips']:
    pose(clip['frames'][0]['arms'],clip); render(clip['name']+'-release.png')
    pose(clip['frames'][2]['arms'],clip)
    # Recovery should not imply another projectile release.
    for o in DYNAMIC:
        if o.name.startswith('needle_'): o.hide_render=True
    render(clip['name']+'-recover.png')
    if clip['name']=='needle_pair': bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rime_m1_pose_proxy.blend'))
if '--motion' in sys.argv:
    # Low-rate offline curve preview, not Roblox AnimationTrack or device performance evidence.
    scene.render.resolution_x=320; scene.render.resolution_y=320; scene.cycles.samples=8
    (OUT/'motion').mkdir(exist_ok=True)
    starts=[0,.25,.5]
    for frame in range(19):
        t=min(frame/10,1.7)
        index=0 if t<.25 else 1 if t<.5 else 2
        clip=SOURCE['clips'][index]; local_t=min(t-starts[index],clip['duration'])
        a,b=clip['frames'][-2:]
        for first,second in zip(clip['frames'],clip['frames'][1:]):
            if first['t']<=local_t<=second['t']: a,b=first,second; break
        weight=max(0,min(1,(local_t-a['t'])/(b['t']-a['t'])))
        angles={n:[v+(w-v)*weight for v,w in zip(a['arms'][n],b['arms'][n])] for n in SOURCE['authoredJoints']}
        pose(angles,clip)
        for o in DYNAMIC:
            if o.name.startswith('needle_') and local_t>.11: o.hide_render=True
        render(f'motion/{frame:02d}.png')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('RIME M1: 3 original closed 16-triangle meshes, six pose renders; no gameplay modified')
