#!/usr/bin/env python3
"""Recover native DS G parameters and select effects supported by desktop rules.

Only derived numeric parameters and decoded descriptions enter project assets;
ARM9 machine code remains in the user's external import staging directory.
"""
import argparse, hashlib, json, struct
from pathlib import Path

ATTRIBUTES = ['Pyrus', 'Aquos', 'Subterra', 'Haos', 'Darkus', 'Ventus']
ID_OFFSET = 0xA10AC
G_OFFSET = 0xA15AC
GATES = [136,217,306,101,103,105,107,109,111,113,125,201,202,203,204,205,207,215,220,301,314,315,322,323,327,331,119]
ABILITIES = [408,527,602,401,402,403,404,405,406,407,511,513,515,516,518,520,524,528,532,601,603,604,605,606,607,608,609,610,611,612,613,614,615,616,617,618,619,620,621,622]
ABILITIES += list(range(409,433)) + list(range(501,511)) + list(range(623,634))
DEFAULT_IDS = {'gate':[119,217,306], 'ability':[408,502,604]}


def sha(d): return hashlib.sha256(d).hexdigest()


def parameter_evidence(native, data, overlay):
    def instructions_at(binary, offset, expected):
        actual=list(struct.unpack_from('<'+'I'*len(expected),binary,offset))
        if actual != expected: raise ValueError('Native parameter accessor instruction sequence changed')
    # Static decode of the tiny ARM function verifies row stride and byte lookup.
    instructions_at(data,0x65BF4,[0xE59F300C,0xE3A02006,0xE0223290,0xE7D10002,0xE12FFF1E,0x020A15AC])
    # The opposed-stand power preparation calls that exact function then ×10.
    instructions_at(overlay,0x23E28,[0xEBF8A261,0xE3A0100A,0xE0010190,0xE1C511B2])
    instructions_at(data,0x65C20,[0xE35000D5,0x23A00000,0x212FFF1E,0xE59F1008,0xE1A00080,0xE19100B0,0xE12FFF1E,0x020A10AC])
    byid={c['source_card_id']:c for c in native['cards']}
    column_checks=[]
    for cid,attribute in [(626,'Pyrus'),(630,'Aquos'),(627,'Subterra'),(628,'Haos'),(629,'Darkus'),(631,'Ventus')]:
        card=byid[cid];i=card['message_index'];row=list(data[G_OFFSET+i*6:G_OFFSET+i*6+6]);expected=[0]*6;expected[ATTRIBUTES.index(attribute)]=20
        if row != expected or f'{attribute} Bakugan gains' not in card['source_description']: raise ValueError('Native Attribute column does not match explicit MES ability')
        column_checks.append({'source_card_id':cid,'message_index':i,'printed_rule':card['source_description'],'attribute':attribute,'column':ATTRIBUTES.index(attribute),'native_g_units':row})
    return {'schema':1,'source_game':native['source_game'],'method':'Static parameter recovery from the user-supplied DS ROM, without running its code. Only data and human-readable assembly summaries enter the game.','decompressed_arm9_sha256':sha(data),'decompressed_overlay_7_sha256':sha(overlay),'native_numeric_id_lookup':{'arm9_offset':'0x65c20','table_offset':hex(ID_OFFSET),'rows':213,'assembly_summary':['CMP r0, #213; return 0 for an out-of-range index','LDR r1, table_address','MOV r0, r0, LSL #1','LDRH r0, [r1, r0]'],'association':'All 213 u16 values equal [0] plus every source_card_id in ascending artwork/MES order.'},'g_byte_lookup':{'arm9_offset':'0x65bf4','table_offset':hex(G_OFFSET),'rows':213,'row_bytes':6,'assembly_summary':['LDR r3, table_address','MOV r2, #6','MLA r2, r0, r2, r3','LDRB r0, [r1, r2]','BX lr'],'formula':'G_units = table[card_index * 6 + attribute_index]'},'battle_power_scale':{'overlay':7,'decompressed_overlay_offset':'0x23e28','runtime_address':'0x0223d268','assembly_summary':['BL 0x02065bf4','MOV r1, #10','MUL r1, r0, r1','STRH r1, [r5, #18]'],'formula':'Displayed/battle Gate G = G_units * 10','additional_scale_call_offsets':['0x295dc','0x2a844']},'attribute_column_checks':column_checks,'executable_code_packaged':False,'limits':['Static data/accessor verification does not claim to reproduce original DS engine timing, minigames or all effect semantics.','The desktop starter selection is not claimed to match the original DS initial inventory.']}


def build(project: Path, arm9: Path, overlay_path: Path | None = None):
    native = json.loads((project/'assets/ds/source_cards.json').read_text())
    data = arm9.read_bytes()
    overlay = (overlay_path or arm9.with_name("ov00007.decompressed")).read_bytes()
    evidence = parameter_evidence(native, data, overlay)
    expected = [0]+[c['source_card_id'] for c in native['cards']]
    found = list(struct.unpack_from('<213H',data,ID_OFFSET))
    if found != expected: raise ValueError('Native numeric ID table differs from MES/artwork indices')
    raw = data[G_OFFSET:G_OFFSET+213*6]
    if len(raw)!=1278 or raw[:6]!=bytes(6) or max(raw)>40: raise ValueError('Unexpected native G table extent')
    byid = {c['source_card_id']:c for c in native['cards']}
    selected = []
    for kind, ids in [('gate',GATES),('ability',ABILITIES)]:
      for cid in ids:
        n=byid[cid]; i=n['message_index']; values=list(raw[i*6:i*6+6]); boosts=dict(zip(ATTRIBUTES,[v*10 for v in values])); effect={};description=''
        if kind=='gate':
          if n['color_type']=='gold':effect={'type':'character_double','species':n['name']};description=f"{n['name']}: бонус ворот удваивается."
          elif n['color_type']=='silver':effect={'type':'none'};description='Бонус стихии ворот применяется при раскрытии.'
          else:
            effect,description={
             301:({'type':'no_abilities'},'В этом бою нельзя играть способности.'),
             306:({'type':'restore_abilities','target':'all'},'Оба игрока возвращают использованные способности.'),
             314:({'type':'ability_multiplier','multiplier':2},'Бонусы G от способностей в этом бою удваиваются.'),
             315:({'type':'double_lowest_printed'},'Меньшее напечатанное G удваивается.'),
             322:({'type':'swap_printed'},'Бакуганы обмениваются напечатанным G.'),
             323:({'type':'swap_printed','required_attribute':'Pyrus'},'Если в бою есть Pyrus, напечатанное G меняется местами.'),
             327:({'type':'used_ability_bonus','bonus':100},'+100 G за каждую использованную владельцем способность.'),
             331:({'type':'captured_gate_bonus','bonus':100},'+100 G за каждые выигранные владельцем ворота.'),
            }[cid]
        else:
          if 401<=cid<=406:effect={'type':'power_swap','own_attribute':ATTRIBUTES[cid-401]};description=f"{ATTRIBUTES[cid-401]}: поменять текущие G бакуганов местами."
          elif cid in (407,408):
            relation='same' if cid==407 else 'different';effect={'type':'power_swap','relationship':relation};description='Поменять текущие G местами, если стихии '+('совпадают.' if cid==407 else 'отличаются.')
          elif 409<=cid<=416 or 425<=cid<=432:
            first=409 if cid<425 else 425; offset=cid-first
            effect={'type':'time_break' if first==409 else 'double_input'}
            if offset<6: effect['own_attribute']=ATTRIBUTES[offset]
            else: effect['relationship']='same' if offset==6 else 'different'
            description='На время остановить ввод соперника.' if first==409 else 'Удвоить силу ввода в мини-игре.'
          elif 417<=cid<=422:
            mode=['scratch','spin','timing','pop','trace','bound'][cid-417]
            effect={'type':'redo','mode':mode};description='Начать бой заново: '+mode.title()+'.'
          elif cid==423: effect={'type':'redo','mode':'current'};description='Начать мини-игру заново.'
          elif cid==424: effect={'type':'level_field'};description='Начать мини-игру заново с равной G-Power.'
          elif 501<=cid<=504:
            family=['redo','swap','time_break','double_input'][cid-501]
            effect={'type':'block_family','family':family};description='Заблокировать у соперника карты типа '+family+'.'
          elif cid in (505,506): effect={'type':'cancel_boost','target':'all' if cid==505 else 'opponent'};description='Отменить бонусы G от способностей: '+('обе стороны.' if cid==505 else 'соперник.')
          elif 507<=cid<=510:
            effect={'type':'skip_battle'}
            if cid>507: effect['gate_color']=['gold','silver','copper'][cid-508]
            description='Пропустить мини-игру: выигрывает большая G-Power.'
          elif 511<=cid<=532:
            species=n['source_description'].split(' gets +200')[0]; effect={'type':'species_bonus','species':species,'bonus':200};description=f'{species} получает +200 G.'
          elif cid in (618,619):effect={'type':'captured_gate_bonus','bonus':50};description='+50 G за каждые выигранные вами ворота.'
          elif cid in (605,614):effect={'type':'gate_owned_power','gate_relation':'own','boosts':boosts};description='Бонус G по стихии, если бой идёт на ваших воротах.'
          elif cid in (606,607,615,616):effect={'type':'gate_owned_power','gate_relation':'opponent','boosts':boosts};description='Бонус G по стихии, если бой идёт на воротах соперника.'
          elif cid in (620,621,622):effect={'type':'higher_opponent_printed_power','boosts':boosts};description='Бонус G по стихии, если напечатанное G соперника выше.'
          elif 623<=cid<=625:
            effect={'type':'hand_combo','required_attributes':[['Pyrus','Darkus'],['Ventus','Haos'],['Subterra','Aquos']][cid-623],'boosts':boosts};description='Комбинация стихий в резерве: '+', '.join(effect['required_attributes'])+'.'
          elif 626<=cid<=631:
            own,other=[('Pyrus','Subterra'),('Subterra','Haos'),('Haos','Darkus'),('Darkus','Aquos'),('Aquos','Ventus'),('Ventus','Pyrus')][cid-626]
            effect={'type':'opponent_combo','own_attribute':own,'opponent_attribute':other,'boosts':boosts};description=own+' против '+other+': бонус G.'
          elif cid in (632,633):
            effect={'type':'team_combo','required_attributes':['Pyrus','Aquos','Haos'] if cid==632 else ['Subterra','Ventus','Darkus'],'boosts':boosts};description='Команда трёх стихий: '+', '.join(effect['required_attributes'])+'.'
          else:effect={'type':'attribute_power','boosts':boosts};description='Бонус G зависит от стихии вашего бакугана.'
        selected.append({'key':n['key'],'source_key':n['key'],'source_card_id':cid,'message_index':i,'title':n['name'].strip(),'name':n['name'].strip(),'kind':kind,'color_type':n['color_type'],'rules_profile':'ds','playable':True,'boosts':boosts,'attributes':ATTRIBUTES if kind=='gate' or cid<600  else [a for a,v in boosts.items() if v>0], 'effect':effect,'type':effect['type'],'bonus':effect.get('bonus',0),'description':description,'printed_rule':n['source_description'],'source_description':n['source_description'],'path':n['path'],'parameter_source':{'decompressed_arm9_offset':hex(G_OFFSET+i*6),'native_card_table_index':i,'native_g_units':values,'multiplier':10},'source_image_sha256':n['image_sha256']})
    parameters=[]
    for n in native['cards']:
      i=n['message_index'];values=list(raw[i*6:i*6+6]);parameters.append({'source_card_id':n['source_card_id'],'message_index':i,'native_g_units':values,'boosts':dict(zip(ATTRIBUTES,[v*10 for v in values])),'playable':n['source_card_id'] in GATES+ABILITIES})
    (project/'assets/ds/card_parameter_evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    return {'schema':1,'source_game':native['source_game'],'provenance':{'source_manifest':'res://assets/ds/source_cards.json','source_manifest_sha256':sha((project/'assets/ds/source_cards.json').read_bytes()),'decompressed_arm9_sha256':sha(data),'id_table_offset':hex(ID_OFFSET),'g_table_offset':hex(G_OFFSET),'g_table_bytes':1278,'g_table_sha256':sha(raw),'entry_count':213,'attribute_order':ATTRIBUTES,'scale':10,'binding_evidence':'ARM9 u16 numeric IDs exactly match all 213 native artwork/MES indices. Six-byte G rows align to the same index.', 'parameter_evidence':'res://assets/ds/card_parameter_evidence.json','rom_code_packaged':False},'counts':{'gates':len(GATES),'abilities':len(ABILITIES),'playable':len(selected),'native_parameter_rows':len(parameters)},'default_ids':DEFAULT_IDS,'cards':selected,'native_parameters':parameters,'limits':['This is a verified desktop starter selection, not a reconstruction of the original DS initial inventory.','Only listed effect types are playable. Native numbers do not imply implementation of all 212 card effects.','Redo/Time Breaker/Double Input use desktop timing; original numeric formulas are not recovered. Battlefield-only special cards remain collection entries.']}


def main():
    p=argparse.ArgumentParser();p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--arm9',type=Path,default=Path('/workspace/bakugan-ds-import/card-param-investigation/arm9.decompressed'));a=p.parse_args();d=build(a.project,a.arm9);out=a.project/'assets/ds/playable_cards.json';out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(json.dumps(d['counts']))
if __name__=='__main__':main()
