"""Blender: measure evaluated native skins for idle and opening, without rendering.

Run: blender --background --factory-startup --python this.py -- PROJECT STAGING
Only role clips are retained in temporary analysis copies; distributed GLBs stay
unchanged. Source coordinates are recovered from Blender's glTF axis conversion.
"""
import bpy
import json
from pathlib import Path
import struct
import sys

args = sys.argv[sys.argv.index('--')+1:]
project, staging = map(Path, args)
staging.mkdir(parents=True, exist_ok=True)
path = project/'assets/doc/models/model_manifest.json'
manifest = json.loads(path.read_text())
scene = bpy.context.scene
scene.render.fps = 60
evidence = {}


def src(v):return [float(v.x),float(v.z),float(-v.y)]


def bounds(arm, meshes, action, frame):
    arm.animation_data.action = action
    scene.frame_set(int(frame), subframe=frame%1)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    points = []
    for mesh in meshes:
        obj = mesh.evaluated_get(dg)
        used = {i for poly in obj.data.polygons for i in poly.vertices}
        points.extend(src(obj.matrix_world@obj.data.vertices[i].co) for i in used)
    if not points:raise ValueError('No evaluated source vertices')
    return {'minimum': [min(v[i] for v in points) for i in range(3)],
            'maximum': [max(v[i] for v in points) for i in range(3)]}


for entry in manifest['species']+manifest['support']:
    for form, definition in list(entry['forms'].items()):
        if form not in ('battle', 'toy'):continue
        clip = definition['animation_roles'].get('idle' if form=='battle' else 'open')
        if not clip:raise ValueError('Missing measurable clip: '+entry['key']+'/'+form)
        for obj in list(bpy.data.objects):bpy.data.objects.remove(obj, do_unlink=True)
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        original = (project/definition['path'].removeprefix('res://')).read_bytes()
        size = struct.unpack_from('<I', original,12)[0]
        doc = json.loads(original[20:20+size])
        doc['animations'] = [a for a in doc.get('animations',[]) if a['name']==clip]
        encoded = json.dumps(doc,separators=(',',':')).encode()
        encoded += b' '*(-len(encoded)%4)
        suffix = original[20+size:]
        analysis = staging/(entry['key']+'_'+form+'.glb')
        analysis.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(suffix))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+suffix)
        bpy.ops.import_scene.gltf(filepath=str(analysis))
        arm = next(o for o in scene.objects if o.type=='ARMATURE' and o.animation_data)
        meshes = [o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
        for track in arm.animation_data.nla_tracks:track.mute=True
        action = next(iter(bpy.data.actions))
        first,last = map(float,action.frame_range)
        samples = [bounds(arm,meshes,action,first+(last-first)*i/20) for i in range(21)]
        minimum = [min(b['minimum'][i] for b in samples) for i in range(3)]
        maximum = [max(b['maximum'][i] for b in samples) for i in range(3)]
        height = (samples[-1]['maximum'][1]-samples[-1]['minimum'][1]) if form=='toy' else maximum[1]-minimum[1]
        scale = min(2.0/height, 3.2/(maximum[0]-minimum[0]), 3.2/(maximum[2]-minimum[2])) if form=='toy' else 2.5/height
        definition['transform'] = {'scale':scale,'position':[-(minimum[0]+maximum[0])*scale/2,-minimum[1]*scale,-(minimum[2]+maximum[2])*scale/2],'rotation_degrees':[0,0,0]}
        definition['normalization'] = {'target_open_height' if form=='toy' else 'target_idle_height':2.0 if form=='toy' else 2.5,'maximum_toy_width_depth':3.2 if form=='toy' else None,'basis':'21 evaluated source skin samples of '+clip,'floor_y':0}
        record = {'clip':clip,'source_sha256':definition['sha256'],'samples':samples,'minimum':minimum,'maximum':maximum,'transform':definition['transform']}
        evidence[entry['key']+'/'+form] = record
        if form=='toy':
            closed = samples[0]
            diameter = max(closed['maximum'][i]-closed['minimum'][i] for i in range(3))
            ball_scale = 0.76/diameter
            ball = dict(definition)
            ball['transform'] = {'scale':ball_scale,'position':[-(closed['minimum'][i]+closed['maximum'][i])*ball_scale/2 for i in range(3)],'rotation_degrees':[0,0,0]}
            ball['normalization'] = {'target_closed_diameter':0.76,'basis':'Evaluated first source opening pose','center':[0,0,0]}
            entry['forms']['ball_pending'] = ball
        print('MEASURED',entry['key'],form,'scale',scale,flush=True)
        (staging/'pose-evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
    if 'ball_pending' in entry['forms']:entry['forms']['ball']=entry['forms'].pop('ball_pending')
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
