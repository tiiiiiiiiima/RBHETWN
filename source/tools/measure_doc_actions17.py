"""Blender source skin floor audit for the selected native ability clips."""
import bpy,json,struct,sys,math
from pathlib import Path
project,staging=map(Path,sys.argv[sys.argv.index('--')+1:])
staging.mkdir(parents=True,exist_ok=True)
path=project/'assets/doc/models/model_manifest.json'
j=json.loads(path.read_text());scene=bpy.context.scene;scene.render.fps=60;results={}
for entry in j['species']:
 f=entry['forms'].get('battle',{});clip=f.get('animation_roles',{}).get('attack')
 if not clip:continue
 for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 original=(project/f['path'].removeprefix('res://')).read_bytes();size=struct.unpack_from('<I',original,12)[0]
 doc=json.loads(original[20:20+size]);doc['animations']=[a for a in doc['animations'] if a['name']==clip]
 encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4);suffix=original[20+size:]
 p=staging/(entry['key']+'.glb');p.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(suffix))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+suffix)
 bpy.ops.import_scene.gltf(filepath=str(p))
 arm=next(o for o in scene.objects if o.type=='ARMATURE' and o.animation_data)
 meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
 for track in arm.animation_data.nla_tracks:track.mute=True
 action=next(iter(bpy.data.actions));arm.animation_data.action=action
 first,last=map(float,action.frame_range);count=max(2,math.ceil(last-first)+1);curve=[];lowest=1e9
 for index in range(count):
  frame=first+(last-first)*index/(count-1);scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();floor=1e9
  for mesh in meshes:
   obj=mesh.evaluated_get(dg);used={i for poly in obj.data.polygons for i in poly.vertices}
   floor=min(floor,min((obj.matrix_world@obj.data.vertices[i].co).z for i in used))
  scale=f['transform']['scale'];world=floor*scale+f['transform']['position'][1];lowest=min(lowest,world)
  curve.append([index*(last-first)/60/(count-1),max(0,-world+0.01)/scale])
 f['desktop_ability_floor']={'source_clip':clip,'curve':curve,'source_minimum_y':lowest,'source_units':True,'adaptation':'Retain original joint tracks; lift Bip01 Y by evaluated native skin floor envelope for the desktop stage'}
 results[entry['key']]={'source_clip':clip,'minimum_stage_y_before_lift':lowest,'samples':count,'maximum_lift_source_units':max(r[1] for r in curve)}
 print('ACTION_FLOOR',entry['key'],round(lowest,5),flush=True)
 (staging/'action-evidence.json').write_text(json.dumps(results,indent=2)+'\n')
path.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
