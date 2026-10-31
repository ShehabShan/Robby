"""Blender FBX/GLB round-trip gate; run after rime_m1.py. No Roblox import claim."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1] / 'build/art/rime_m1'
results=[]
for ext in ['fbx','glb']:
    for name in ['needle_left','needle_right','needle_pair']:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        p=root/(name+'.'+ext)
        if ext=='fbx': bpy.ops.import_scene.fbx(filepath=str(p))
        else: bpy.ops.import_scene.gltf(filepath=str(p))
        obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
        vertices=[obj.matrix_world @ v.co for v in obj.data.vertices]
        size=[round(max(v[i] for v in vertices)-min(v[i] for v in vertices),4) for i in range(3)]
        assert size[1]==1.8 and size[0]<.4 and size[2]<.3,(ext,name,size)
        tip=max(vertices,key=lambda v:v.y)
        assert abs(tip.y-.95)<1e-5
        results.append({'file':p.name,'roundtrip_size':size,'forward_tip_blender_y':round(tip.y,3)})
(root/'export_validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('EXPORT ROUNDTRIP: PASS (6 files; 1.8 stud length; +Y forward restored)')
