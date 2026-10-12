#!/usr/bin/env python3
"""Export bounded native SRT samples for the existing GLB materials; no ROM/code included."""
import json, struct, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RAW=Path('/workspace/bakugan-ds-import/arena-nitro')
def dictionary(b,base,width):
 n=b[base+1]; data=base+16+4*n; names=data+n*width
 assert struct.unpack_from('<H',b,base+12+4*n)[0]==width
 assert names+16*n<=len(b)
 return [(b[data+i*width:data+(i+1)*width],b[names+16*i:names+16*(i+1)].rstrip(b'\0').decode()) for i in range(n)]
def channel(b,base,data,axis,frames):
 end,_,flags,offset=struct.unpack('<HBBI',data)
 if flags & 0x20:
  if axis==2:return {'constant':0.0,'raw_flags':flags,'identity_rotation':offset==0x10000000}
  v=offset if offset<2**31 else offset-2**32
  return {'constant':v/4096,'raw_flags':flags}
 step=1<<((flags>>6)&3)
 count=end//step+max(0,frames-end)
 assert count>0
 short=bool(flags&0x10); size=2 if short else 4
 assert base+offset+count*size<=len(b)
 values=struct.unpack_from('<'+('h' if short else 'i')*count,b,base+offset)
 # SDK GetTexSRTAnmVectorVal_ sign-extends fx16 without shifting it.
 # Both widths use 12 fractional bits. Dividing fx16 by 32 made UV
 # movement 128 times too large (a native 4096 sample is one UV unit).
 return {'values':[v/4096 for v in values],'step':step,'interpolation_end':end,'raw_flags':flags,'source_offset':base+offset}
def colour_channel(b,base,data,axis,frames):
 """SDK MAT0 descriptor: constant bit29, end bits16..28, stride bits30..31.

 Alpha samples are bytes; diffuse/ambient/specular/emission are RGB555 u16.
 Keep the native compact samples and quantization; do not interpolate packed RGB.
 """
 word=struct.unpack('<I',data)[0]
 flags=word>>24
 offset=word&0xffff
 if word&0x20000000:
  assert offset <= (31 if axis==4 else 0x7fff)
  return {'constant':offset,'raw_descriptor':word}
 decimation=word>>30
 assert decimation in (0,1,2), 'Reserved MAT0 decimation'
 step=1<<decimation
 end=(word>>16)&0x1fff
 count=frames if step==1 else end//step+max(0,frames-end)
 size=1 if axis==4 else 2
 assert count>0 and base+offset+count*size<=len(b), 'MAT0 samples outside bounded source'
 values=list(struct.unpack_from('<'+('B' if axis==4 else 'H')*count,b,base+offset))
 assert all(v <= (31 if axis==4 else 0x7fff) for v in values)
 return {'values':values,'step':step,'interpolation_end':end,'raw_descriptor':word,'source_offset':base+offset}
def main():
 manifest=json.loads((ROOT/'assets/ds/arenas/arena_manifest.json').read_text())
 result={'schema':2,'source_rom_sha256':manifest['source']['rom_sha256'],'fps':60,'groups':{},'colour_groups':{},'format_reference':'https://github.com/pret/pokediamond/blob/master/arm9/asm/NNS_G3D_nsbma.s','limits':'Native SRT and MAT0 samples. Desktop material lighting and alpha rendering are adaptations; gameplay hazard logic, BVA and PAT are separate.'}
 for group,g in manifest['groups'].items():
  result['groups'][group]={}
  result['colour_groups'][group]={}
  for comp in g['components']:
   matches=[]
   for source in comp.get('source_animations',[]):
    prefix=source['path'].replace('/','__').replace('.','_')+'__'
    matches.extend(RAW.glob(prefix+'*.nsbta'))
   for path in matches:
    b=path.read_bytes();block=struct.unpack_from('<I',b,16)[0];assert b[block:block+4]==b'SRT0'
    for data,name in dictionary(b,block+8,4):
     base=block+struct.unpack('<I',data)[0];assert b[base:base+4]==b'M\0AT'
     frames=struct.unpack_from('<H',b,base+4)[0]
     tracks=[]
     for values,mat in dictionary(b,base+8,40):
      channels=[channel(b,base,values[i*8:i*8+8],i,frames) for i in range(5)]
      assert channels[0].get('constant')==1 and channels[1].get('constant')==1 and channels[2].get('identity_rotation'), (group,mat)
      tracks.append({'name':mat,'channels':channels})
     result['groups'][group][comp['id']]={'name':name,'frames':frames,'tracks':tracks,'source_file':path.name,'source_sha256':hashlib.sha256(b).hexdigest()}
   colour_matches=[]
   for source in comp.get('source_animations',[]):
    prefix=source['path'].replace('/','__').replace('.','_')+'__'
    colour_matches.extend(RAW.glob(prefix+'*.nsbma'))
   for path in colour_matches:
    b=path.read_bytes();block=struct.unpack_from('<I',b,16)[0];assert b[block:block+4]==b'MAT0'
    for data,name in dictionary(b,block+8,4):
     base=block+struct.unpack('<I',data)[0];assert b[base:base+4]==b'M\0AM'
     frames=struct.unpack_from('<H',b,base+4)[0]
     assert frames>0
     tracks=[]
     for values,mat in dictionary(b,base+8,20):
      channels=[colour_channel(b,base,values[i*4:i*4+4],i,frames) for i in range(5)]
      tracks.append({'name':mat,'channels':channels})
     result['colour_groups'][group][comp['id']]={'name':name,'frames':frames,'tracks':tracks,'source_file':path.name,'source_sha256':hashlib.sha256(b).hexdigest()}
 out=ROOT/'assets/ds/arenas/material_motion.json';out.write_text(json.dumps(result,separators=(',',':'))+'\n')
 print(json.dumps({'components':sum(len(g) for g in result['groups'].values()),'tracks':sum(len(c['tracks']) for g in result['groups'].values() for c in g.values()),'colour_components':sum(len(g) for g in result['colour_groups'].values()),'colour_tracks':sum(len(c['tracks']) for g in result['colour_groups'].values() for c in g.values()),'bytes':out.stat().st_size}))
if __name__=='__main__':main()
