#!/usr/bin/env python3
"""Import named DoC DS forms; preserve native meshes, UVs, skins and joint clips.

Input is extracted user NitroFS, outside the distributable project. This explicit
mapping must be visually reviewed against the two different source name tables.
DoC calls some anime evolutions by different names; those labels stay recorded.
"""
import argparse
import json
from pathlib import Path
import subprocess

from import_ds_arenas import prepare, digest, embedded_glb
from import_ds_models import clean_animation_names, glb_summary
from decode_ds_messages import read_message_table

# resource, canonical identity, label, native attribute, source name index
BATTLE = [
    ('rb00', 'neo_dragonoid', 'Neo Dragonoid', 'Pyrus', 0),
    ('rb00_01', 'maxus_dragonoid', 'Maxus Dragonoid', 'Pyrus', 1),
    ('rb01', 'ingram', 'Ingram', 'Ventus', 2),
    ('rb01_00', 'master_ingram', 'Master Ingram', 'Ventus', 3),
    ('rb02', 'elfin', 'Elfin', 'Aquos', 4),
    ('rb03', 'percival', 'Percival', 'Darkus', 5),
    ('rb04', 'thunder_wilda', 'Thunder Wilda', 'Subterra', 6),
    ('rb05', 'mega_nemus', 'Mega Nemus', 'Haos', 7),
    ('rb06', 'cyborg_helios', 'Cyborg Helios', 'Pyrus', 8),
    ('rb06_01', 'maxus_helios', 'Maxus Helios', 'Pyrus', 9),
    ('rb07', 'elico', 'Elico', 'Aquos', 10),
    ('rb08', 'mega_brontes', 'Mega Brontes', 'Haos', 11),
    ('rb09', 'premo_vulcan', 'Premo Vulcan', 'Subterra', 12),
    ('rb10', 'hades', 'Hades', 'Darkus', 13),
    ('rb11', 'altair', 'Altair', 'Ventus', 14),
    ('rb00_00', 'cross_dragonoid', 'Cross Dragonoid', 'Pyrus', 15),
    ('rb02_00', 'minx_elfin', 'Minx Elfin', 'Aquos', 16),
    ('rb03_00', 'knight_percival', 'Knight Percival', 'Darkus', 17),
    ('rb04_00', 'magma_wilda', 'Magma Wilda', 'Subterra', 18),
    ('rb05_00', 'saint_nemus', 'Saint Nemus', 'Haos', 19),
]
TRAPS = [
    ('tb00', 'scorpion', 'Scorpion', 'Pyrus', 20),
    ('tb01', 'hylash', 'Hylash', 'Ventus', 21),
    ('tb02', 'tripod_epsilon', 'Tripod Epsilon', 'Aquos', 22),
    ('tb03', 'falcon_fly', 'Falcon Fly', 'Darkus', 23),
    ('tb04', 'baliton', 'Baliton', 'Subterra', 24),
    ('tb05', 'piercian', 'Piercian', 'Haos', 25),
    ('tb06', 'metal_fencer', 'Metal Fencer', 'Pyrus', 26),
    ('tb07', 'tripod_theta', 'Tripod Theta', 'Aquos', 27),
    ('tb08', 'dynamo', 'Dynamo', 'Haos', 28),
    ('tb09', 'hexados', 'Hexados', 'Subterra', 29),
    ('tb10', 'fortress', 'Fortress', 'Darkus', 30),
    ('tb11', 'wired', 'Wired', 'Ventus', 31),
]
# Sphere labels deliberately differ for these evolutions. Do not attach the
# Hyper/Cosmic/Thunder toys to Cross/Master/Magma under a fabricated identity.
SPHERES = [
    ('sp'+stem[2:], key, label, attribute, index)
    for stem, key, label, attribute, index in BATTLE if index not in (1, 9, 3, 15, 18)
] + [
    ('sp01_00', 'cosmic_ingram', 'Cosmic Ingram', 'Ventus', 3),
    ('sp00_00', 'hyper_dragonoid', 'Hyper Dragonoid', 'Pyrus', 15),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('raw_root', type=Path)
    p.add_argument('--apicula', type=Path, required=True)
    p.add_argument('--staging', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--inventory', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    a.staging.mkdir(parents=True, exist_ok=True)
    inventory = json.loads(a.inventory.read_text())
    names = read_message_table(a.raw_root/'font/mes_BakuganName.mes', a.raw_root)
    toy_names = read_message_table(a.raw_root/'font/mes_bakugan_sphere_name.mes', a.raw_root)
    manifest = {'schema_version': 1, 'source': inventory['rom'],
                'archive_sha256': inventory['source']['sha256'],
                'conversion': {'tool': 'apicula', 'binary_sha256': digest(a.apicula.read_bytes()),
                    'unsupported': ['material/visibility/pattern animation', 'source game event dispatcher'],
                    'native_motion_roles': 'Source stay/ability/stagger names; desktop routing, not original combat logic'},
                'species': [], 'support': [], 'warnings': [], 'failures': [],
                'name_tables': [names, toy_names],
                'unmapped_forms': [
                    {'resource': 'sp04_00', 'reason': 'Sphere table calls this THUNDER WILDA; do not silently pair it with MAGMA WILDA battle identity'},
                    {'resource': 'sp12', 'reason': 'No matching source open-animation bundle or name-table mapping'},
                ]}
    by_key = {}

    def convert(row, category, form, folder):
        stem, key, name, attribute, index = row
        if key == 'fortress' and form == 'toy':attribute = 'Darkus'
        entry = by_key.setdefault(key, {'key': key, 'name': name, 'classification': category,
                                        'forms': {}, 'source': 'User-supplied Defenders of the Core DS'})
        st = a.staging/(stem+'_'+form)
        st.mkdir(exist_ok=True)
        files, sources = [], []
        suffixes = ['.nsbmd', '.nsbtx', '_data.bin']
        if form == 'battle':
            suffixes.append('_figure_data.bin')
        for suffix in suffixes:
            relative = f'3d/{folder}/L/{stem}{suffix}'
            if not (a.raw_root/relative).exists():
                if suffix == '_figure_data.bin':continue
                raise ValueError('Missing companion '+relative)
            parts, source = prepare(a.raw_root, st, relative)
            files.extend(parts);sources.append(source)
        out = st/'converted'
        result = subprocess.run([str(a.apicula), 'convert', '-f=glb', '--overwrite',
                                 *map(str, files), '-o', str(out)], capture_output=True, text=True)
        text = result.stdout+result.stderr
        if result.returncode or "couldn't be found" in text:
            raise ValueError(text[-2000:])
        glbs = list(out.glob('*.glb'))
        if len(glbs) != 1:raise ValueError('Expected one model: '+stem)
        destination = a.output/(key+'_'+form+'.glb')
        destination.write_bytes(clean_animation_names(embedded_glb(glbs[0])))
        summary = glb_summary(destination)
        clips = {c['name'] for c in summary['animations']}
        roles = {}
        if form == 'battle':
            for role, clip in [('idle','stay'),('attack','ability01_a'),('damage','f_stagger')]:
                if clip in clips:roles[role]=clip
        elif stem in clips:roles['open']=stem
        table = names if form == 'battle' else toy_names
        source_name = table['records'][index]['text'].strip() if index is not None else 'Unmapped source label; geometry identity requires visual review'
        definition = {'path': 'res://assets/doc/models/'+destination.name,
                      'sha256': digest(destination.read_bytes()), 'size_bytes': destination.stat().st_size,
                      **summary, 'animation_roles': roles, 'native_attribute': attribute,
                      'native_geometry': True, 'native_texture_coordinates': True,
                      'double_sided': False, 'source_name': source_name, 'source_name_index': index,
                      'identity_status': 'Explicit resource mapping awaiting visual review',
                      'source': {'origin': 'user_doc_nitrofs', 'rom_sha256': inventory['rom']['sha256'],
                                 'files': sources, 'resource_stem': stem}}
        entry['forms'][form] = definition
        if '[ERROR]' in text or '[WARN]' in text:
            manifest['warnings'].append({'resource': stem, 'converter_log': text.strip()})
        print(key,form,len(clips),'clips',flush=True)

    for rows, category, form, folder in [(BATTLE,'bakugan','battle','Bakugan_Real'),
                                       (TRAPS,'trap','battle','Bakugan_Trap'),
                                       (SPHERES,'bakugan','toy','Bakugan_Sphere'),
                                       ([('spt'+r[0][2:],*r[1:]) for r in TRAPS],'trap','toy','Bakugan_TrapSphere')]:
        for row in rows:
            try:convert(row,category,form,folder)
            except Exception as exc:manifest['failures'].append({'resource':row[0], 'form':form, 'error':str(exc)})
    for entry in by_key.values():
        if entry['forms']:
            manifest['support' if entry['classification']=='trap' else 'species'].append(entry)
    (a.output/'model_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Imported',len(manifest['species']),'species',len(manifest['support']),'traps; failures',len(manifest['failures']))
    if manifest['failures']:raise SystemExit(1)


if __name__ == '__main__':main()
