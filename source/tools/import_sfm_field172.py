#!/usr/bin/env python3
"""Convert the audited static MDL49/VVD4/VTX7 Workshop field to glTF.

This deliberately accepts the single source asset, not arbitrary Source models.
No downloaded code is run. Native vertices, normals, UVs and material splits are
retained; Source clockwise indices become glTF counter-clockwise triangles.
VTF DXT5 top mips are decoded at native resolution. The one-frame idle does not
become an invented animation. Source files and hashes are kept in the manifest.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
from PIL import Image


def u32(data, offset): return struct.unpack_from('<I', data, offset)[0]
def string(data, offset): return data[offset:data.index(0, offset)].decode('utf-8')
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def convert_axis(v): return [v[0], v[2], -v[1]]
def block_bytes(w, h, size): return max(1, (w+3)//4)*max(1, (h+3)//4)*size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    source = args.source
    destination = args.project/'assets/sfm/battle_field'
    destination.mkdir(parents=True, exist_ok=True)
    paths = {suffix: next(source.rglob('*'+suffix)) for suffix in ('.mdl', '.vvd', '.vtx')}
    mdl, vvd, vtx = (paths[s].read_bytes() for s in ('.mdl', '.vvd', '.vtx'))
    assert mdl[:4] == b'IDST' and u32(mdl,4) == 49
    assert vvd[:4] == b'IDSV' and u32(vvd,4) == 4 and u32(vtx,0) == 7
    assert u32(mdl,8) == u32(vvd,8) == u32(vtx,16), 'Source checksums differ'
    assert u32(vvd,12) == 1 and u32(vvd,48) == 0, 'Only the audited single LOD is supported'
    assert u32(mdl,156) == 1 and u32(mdl,180) == 1 and u32(mdl,188) == 1
    anim = u32(mdl,184)
    assert u32(mdl,anim+16) == 1, 'Source idle has more than one frame'
    assert u32(mdl,232) == 1 and u32(vtx,28) == 1
    body = u32(mdl,236)
    assert u32(mdl,body+4) == 1
    model = body + u32(mdl,body+12)
    assert u32(mdl,model+80) == u32(vvd,16) == 472 and u32(mdl,model+84) == 0
    vbody = u32(vtx,32); vmodel = vbody + u32(vtx,vbody+4)
    assert u32(vtx,vbody) == u32(vtx,vmodel) == 1
    lod = vmodel + u32(vtx,vmodel+4)
    assert u32(vtx,lod) == u32(mdl,model+72) == 9
    names = []
    for i in range(u32(mdl,204)):
        base = u32(mdl,208)+i*64
        names.append(string(mdl,base+u32(mdl,base)).lower())
    assert names == ['ventus','subterra','haos','aquos','pyrus','darkus','floor','fog','black']
    vertices = []
    for i in range(u32(vvd,16)):
        base = u32(vvd,56)+i*48
        assert vvd[base+15] == 1 and vvd[base+12] == 0
        vertices.append((convert_axis(struct.unpack_from('<3f',vvd,base+16)),
                         convert_axis(struct.unpack_from('<3f',vvd,base+28)),
                         list(struct.unpack_from('<2f',vvd,base+40))))
    textures = []
    for name in names:
        path = next(source.rglob(name+'.vtf')); data = path.read_bytes()
        assert data[:4] == b'VTF\0' and struct.unpack_from('<2I',data,4) == (7,2)
        width,height = struct.unpack_from('<2H',data,16)
        assert struct.unpack_from('<2H',data,24) == (1,0) and u32(data,52) == 15
        assert struct.unpack_from('<H',data,63)[0] == 1
        low_format = u32(data,57)
        low_size = block_bytes(data[61], data[62], 8) if low_format == 13 else 0
        mip_sizes = [block_bytes(max(1,width>>i), max(1,height>>i),16) for i in range(data[56])]
        high_offset = u32(data,12)+low_size+sum(mip_sizes[1:])
        assert high_offset+mip_sizes[0] == len(data)
        image = Image.frombytes('RGBA',(width,height),data[high_offset:],'bcn',3)
        target = destination/(name+'.png'); image.save(target)
        vmt = next(source.rglob(name+'.vmt'))
        assert '"$nocull" 1' in vmt.read_text() and '$translucent' not in vmt.read_text()
        textures.append({'name':name,'path':'res://'+str(target.relative_to(args.project)),
                         'dimensions':[width,height],'sha256':digest(target),
                         'decoded_pixel_sha256':hashlib.sha256(image.tobytes()).hexdigest(),
                         'source_vtf':str(path.relative_to(source)),'source_vtf_sha256':digest(path),
                         'source_vmt':str(vmt.relative_to(source)),'source_vmt_sha256':digest(vmt),
                         'decode':'DXT5/BC3 highest native mip to PNG, no resizing/repainting'})
    document = {'asset':{'version':'2.0','generator':'Bakugan static Source field audit 0.17.2'},
                'scenes':[{'nodes':list(range(9))}],'scene':0,'nodes':[], 'meshes':[],
                'images':[{'uri':n+'.png'} for n in names],
                'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
                'textures':[{'source':i,'sampler':0} for i in range(9)],
                'materials':[{'name':n,'doubleSided':True,'alphaMode':'OPAQUE',
                              'pbrMetallicRoughness':{'baseColorTexture':{'index':i},'metallicFactor':0,'roughnessFactor':1}}
                             for i,n in enumerate(names)],
                'bufferViews':[],'accessors':[],'buffers':[]}
    buffer = bytearray(); meshes = []
    def add(values, components, component_type=5126):
        while len(buffer)%4:buffer.append(0)
        start = len(buffer)
        if component_type == 5126:
            flat = [x for v in values for x in v]
            buffer.extend(struct.pack('<'+'f'*len(flat),*flat))
        else:buffer.extend(struct.pack('<'+'H'*len(values),*values))
        view = len(document['bufferViews'])
        document['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(buffer)-start})
        accessor = {'bufferView':view,'componentType':component_type,'count':len(values),'type':{1:'SCALAR',2:'VEC2',3:'VEC3'}[components]}
        if components == 3:
            accessor['min']=[min(v[a] for v in values) for a in range(3)]
            accessor['max']=[max(v[a] for v in values) for a in range(3)]
        index = len(document['accessors']); document['accessors'].append(accessor);return index
    mb = model+u32(mdl,model+76); vb = lod+u32(vtx,lod+4)
    for i in range(9):
        mesh_offset = mb+i*116
        material,count,offset = u32(mdl,mesh_offset),u32(mdl,mesh_offset+8),u32(mdl,mesh_offset+12)
        vmesh = vb+i*9
        assert u32(vtx,vmesh) == 1
        group = vmesh+u32(vtx,vmesh+4)
        assert u32(vtx,group+16) == 1
        vertex_base = group+u32(vtx,group+4)
        original_indices = [struct.unpack_from('<H',vtx,vertex_base+j*9+4)[0] for j in range(u32(vtx,group))]
        assert all(j<count for j in original_indices)
        strip = group+u32(vtx,group+20)
        assert vtx[strip+18] & 1 and not vtx[strip+18] & 2
        index_base = group+u32(vtx,group+12)+u32(vtx,strip+4)*2
        native_indices = struct.unpack_from('<'+'H'*u32(vtx,strip),vtx,index_base)
        indices = [original_indices[j] for j in native_indices]
        assert len(indices)%3 == 0
        # Source render indices wind clockwise; glTF front faces wind CCW.
        indices = [k for j in range(0,len(indices),3) for k in (indices[j],indices[j+2],indices[j+1])]
        local = vertices[offset:offset+count]
        positions,normals,uvs = ([v[n] for v in local] for n in range(3))
        primitive = {'attributes':{'POSITION':add(positions,3),'NORMAL':add(normals,3),'TEXCOORD_0':add(uvs,2)},'indices':add(indices,1,5123),'material':material}
        document['meshes'].append({'name':names[material],'primitives':[primitive]})
        document['nodes'].append({'name':names[material],'mesh':i})
        meshes.append({'material':names[material],'vertices':count,'triangles':len(indices)//3,
                       'minimum':[min(v[a] for v in positions) for a in range(3)],
                       'maximum':[max(v[a] for v in positions) for a in range(3)]})
    document['buffers']=[{'byteLength':len(buffer)}]
    encoded = json.dumps(document,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
    buffer += b'\0'*(-len(buffer)%4)
    glb = struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(buffer))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(buffer),0x004e4942)+buffer
    target = destination/'battle_field.glb';target.write_bytes(glb)
    # Keep cameras inside the shell and every source floor/fog point below the
    # shared PC plane. Uniform scale preserves the original silhouette/UVs.
    floor_y = max(m['maximum'][1] for m in meshes if m['material'] in ('floor','fog'))
    files = [{'path':str(p.relative_to(source)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(source.rglob('*')) if p.is_file()]
    manifest = {'schema':1,'source':{'workshop_id':'3256465343','title':'[Bakugan] Battle Field',
                'workshop_url':'https://steamcommunity.com/sharedfiles/filedetails/?id=3256465343','application':'Source Filmmaker','app_id':1840,
                'author':'PenDragon','archive_bytes':args.archive.stat().st_size,'archive_sha256':digest(args.archive),'files':files},
                'model':{'path':'res://'+str(target.relative_to(args.project)),'sha256':digest(target),
                         'vertices':472,'triangles':sum(m['triangles'] for m in meshes),'materials':9,
                         'source_uv_preserved':True,'source_rest_geometry_preserved':True,'meshes':meshes},
                'textures':textures,'source_animation':{'sequences':1,'label':'idle','frames':1,'fps':30,
                         'motion_present':False,'exported_animation_clips':0},
                'availability':{'bakugan_models':0,'cards':0,'arenas':1,'new_motion_clips':0},
                'pc_fit':{'uniform_scale':0.05,'source_offset':[0,-floor_y,0],
                          'floor_plane':0,'camera_far':120,
                          'adaptation':'Uniform scale, Z-up to Y-up conversion and floor/fog ceiling anchored below the shared PC play plane. Original geometry/UVs/material splits retained. Throw rules and physics remain the existing PC profile; SFM has no game rules.'}}
    (destination/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'model':str(target),'vertices':472,'triangles':manifest['model']['triangles'],'materials':9,'animation_frames':1,'cards':0,'creature_models':0},indent=2))

if __name__ == '__main__':main()
