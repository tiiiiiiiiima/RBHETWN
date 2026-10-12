#!/usr/bin/env python3
"""Import native DS brawler meshes with their own joint animations, no static fallback."""
import sys,json,subprocess,struct
from pathlib import Path
from import_ds_arenas import prepare,embedded_glb,remove_unmapped_animation_channels,digest
from import_ds_models import clean_animation_names,glb_doc
from decode_ds_messages import read_message_table
ROOT=Path(__file__).resolve().parents[1]
RAW=Path('/workspace/bakugan-ds-import/raw')
TOOL=Path('/workspace/bakugan-ds-import/toolchain/apicula-master/target/release/apicula')
STAGE=Path('/tmp/bakugan021-avatars'); STAGE.mkdir(exist_ok=True)
OUT=ROOT/'assets/ds/avatars';OUT.mkdir(exist_ok=True)
names=read_message_table(RAW/'font/mes_StoryCharaName.mes',RAW)
RUSSIAN=['Дэн','Руно','Маручо','Шун','Джули','Элис','Маскарад','Мардук','Билли','Клаус','Чан Ли','Джулио','Комба','Шуджи','Акира','Джулс','Дженни','Джо','Хэл-Джи']
manifest={'schema':1,'origin':'user_ds_nitrofs','source_root':'Game/Character/Character','conversion':'apicula, original joint BCA0, embedded GLB','unsupported':'Material/visibility animation is not exported as joint motion.','avatars':{},'failures':[]}
for model in sorted((RAW/'Game/Character/Character').glob('chara*.nsbmd')):
    stem=model.stem; work=STAGE/stem; work.mkdir(exist_ok=True); files=[]; records=[]
    sources=[model,model.with_suffix('.nsbtx'),*sorted(model.parent.glob(stem+'_*_data.bin'))]
    for source in sources:
        if not source.is_file():continue
        parts,record=prepare(RAW,work,str(source.relative_to(RAW)));files+=parts; records.append(record)
    converted=work/'converted'
    run=subprocess.run([str(TOOL),'convert','-f=glb','--overwrite',*map(str,files),'-o',str(converted)],capture_output=True,text=True)
    output=list(converted.glob('*.glb')) if run.returncode==0 else []
    if len(output)!=1:manifest['failures'].append({'id':stem,'error':run.stderr[-1000:]});continue
    data=embedded_glb(output[0]);data,removed=remove_unmapped_animation_channels(data);data=clean_animation_names(data)
    target=OUT/(stem+'.glb');target.write_bytes(data); doc,_=glb_doc(target)
    animations=[{'name':a.get('name',''),'channels':len(a.get('channels',[]))} for a in doc.get('animations',[])]
    if not animations:target.unlink();manifest['failures'].append({'id':stem,'error':'No exported joint animation'});continue
    manifest['avatars'][stem]={'id':stem,'name':RUSSIAN[int(stem[5:])],'original_name':names['records'][int(stem[5:])]['text'],'name_source':names['source_path'],'name_source_sha256':names['source_sha256'],'name_index':int(stem[5:]),'path':'res://'+str(target.relative_to(ROOT)),'source_files':records,'animations':animations,'animation_count':len(animations),'removed_material_channels':removed,'sha256':digest(data),'identity':'native indexed name; visual verification required after reconversion'}
    print(stem,len(animations),len(data),flush=True)
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Native animated avatars:',len(manifest['avatars']),'failures',manifest['failures'])
