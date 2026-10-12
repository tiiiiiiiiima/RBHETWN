#!/usr/bin/env python3
"""Check recovered source parameters against real source instructions and MES.

The source files stay outside the project and are never executed.
"""
import argparse
import json
from pathlib import Path
from build_ds_playable_catalog import parameter_evidence


def main():
    p=argparse.ArgumentParser();p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--staging',type=Path,default=Path('/workspace/bakugan-ds-import/card-param-investigation'));a=p.parse_args()
    native=json.loads((a.project/'assets/ds/source_cards.json').read_text());arm=(a.staging/'arm9.decompressed').read_bytes();ov=(a.staging/'ov00007.decompressed').read_bytes()
    checks=0
    evidence=parameter_evidence(native,arm,ov);assert len(evidence['attribute_column_checks'])==6;checks+=1
    for which,offset in [('arm',0x65BF8),('arm',0x65C20),('ov',0x23E2C)]:
        damaged=bytearray(arm if which=='arm' else ov);damaged[offset]^=1
        try:parameter_evidence(native,bytes(damaged) if which=='arm' else arm,bytes(damaged) if which=='ov' else ov)
        except ValueError:checks+=1
        else:raise AssertionError('corrupted native accessor accepted')
    row=next(c for c in native['cards'] if c['source_card_id']==626)['message_index'];damaged=bytearray(arm);start=0xA15AC+row*6;damaged[start:start+2]=bytes([0,20])
    try:parameter_evidence(native,bytes(damaged),ov)
    except ValueError:checks+=1
    else:raise AssertionError('wrong native attribute column accepted')
    manifest=json.loads((a.project/'assets/ds/playable_cards.json').read_text());byid={c['source_card_id']:c for c in manifest['cards']}
    assert byid[101]['parameter_source']['native_g_units']==[15,5,7,3,5,4];checks+=1
    assert byid[101]['boosts']['Pyrus']==150;checks+=1
    assert byid[602]['boosts']=={'Pyrus':60,'Aquos':0,'Subterra':60,'Haos':0,'Darkus':60,'Ventus':0};checks+=1
    assert manifest['counts']=={'gates':26,'abilities':40,'playable':66,'native_parameter_rows':212};checks+=1
    print(json.dumps({'test':'ds_native_parameter_recovery','checks':checks,'failures':[]}))
if __name__=='__main__':main()
