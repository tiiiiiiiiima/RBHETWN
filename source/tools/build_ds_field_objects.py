#!/usr/bin/env python3
"""Import native DS field objects and bounded SetData placement records.

Only decoded assets, placements and provenance enter the game. Original code,
ROM and Nitro binaries stay outside it. Type/field associations are documented
inferences; impulse strengths, rewards and reset policy are desktop choices.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

from import_ds_arenas import prepare, embedded_glb, remove_unmapped_animation_channels, decompress_lz10
from build_ds_material_motion import dictionary, channel
from decode_ds_messages import read_message_table

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ['toy', 'pyrus', 'aquos', 'subterra', 'haos', 'darkus', 'ventus', 'anime']
OBJECTS = {1: ('g_power', 'fieldpower_g_0'), 2: ('s_power', 'fieldpower_s_0'),
           9: ('s_power_small', 'fieldpower_s_1'), 3: ('field_card', 'ability_filed0'), 4: ('trampoline', 'jumpobj_00'),
           5: ('speed_pad', 'dashbase_00'), 30: ('lava_pool', 'Pyruseruption_n'),
           7: ('experience', 'exepoint_00'), 6: ('breakable', 'fielddestroy_n_0'),
           41: ('water_jet', 'aqousfukidasi_n'), 60: ('energy_orb', 'Haosball'),
           82: ('wind_jet', 'ventkaze0')}


def parse_placements(data):
    if len(data) < 4:
        raise ValueError('Truncated SetData header')
    flags, count = struct.unpack_from('<HH', data)
    if count > 4096 or len(data) != 4 + count * 32:
        raise ValueError('SetData count does not match bounded 32-byte records')
    records = []
    for index in range(count):
        values = struct.unpack_from('<6i3H2B', data, 4 + index * 32)
        position = [v / 4096 for v in values[:3]]
        extent = [v / 4096 for v in values[3:6]]
        if any(abs(v) > 100000 for v in position) or any(v <= 0 or v > 100000 for v in extent):
            raise ValueError('Invalid SetData position/extent')
        kind = OBJECTS.get(values[10], ('unsupported', ''))[0]
        records.append({'index': index, 'position': position, 'extent': extent,
                        'rotation_u16': list(values[6:9]), 'parameter': values[9],
                        'type_id': values[10], 'kind': kind})
    return {'header_flags': flags, 'count': count, 'records': records}


def srt_entry(paths):
    entry = {}
    for path in paths:
        if path.suffix != '.nsbta':
            continue
        data = path.read_bytes()
        block = struct.unpack_from('<I', data, 16)[0]
        assert data[block:block+4] == b'SRT0'
        for offset, name in dictionary(data, block + 8, 4):
            base = block + struct.unpack('<I', offset)[0]
            frames = struct.unpack_from('<H', data, base + 4)[0]
            tracks = []
            for values, material in dictionary(data, base + 8, 40):
                channels = [channel(data, base, values[i*8:i*8+8], i, frames) for i in range(5)]
                assert channels[0].get('constant') == 1 and channels[1].get('constant') == 1
                assert channels[2].get('identity_rotation')
                tracks.append({'name': material, 'channels': channels})
            entry = {'name': name, 'frames': frames, 'tracks': tracks,
                     'source_sha256': hashlib.sha256(data).hexdigest()}
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', type=Path, default=Path('/workspace/bakugan-ds-import/raw'))
    parser.add_argument('--stage', type=Path, default=Path('/workspace/bakugan-ds-import/field-objects15'))
    parser.add_argument('--apicula', type=Path, default=Path('/workspace/bakugan-ds-import/toolchain/apicula-master/target/release/apicula'))
    args = parser.parse_args()
    destination = ROOT / 'assets/ds/field_objects'
    destination.mkdir(exist_ok=True)
    args.stage.mkdir(exist_ok=True)
    result = {'schema': 1, 'source_rom_sha256': json.loads((ROOT/'assets/ds/arenas/arena_manifest.json').read_text())['source']['rom_sha256'],
              'format': 'u16 header, u16 count; count * (6 fx32, 3 u16 angles, u8 parameter, u8 type)',
              'mapping_evidence': 'Type/field associations inferred from source names, native textures, placement patterns and MES tips; original dispatcher not recovered.',
              'desktop_parameters': {'g_reward': 20, 's_reward': 25, 's_small_reward': 10,
                                     'max_g_per_throw': 120, 's_meter_max': 100,
                                     'speed_boost': 4.0, 'trampoline_impulse': 6.5,
                                     'pad_cooldown_seconds': 0.45, 'pickup_reset': 'new match',
                                     'experience_reward': 5, 'breakable_speed_scaled': 7.0,
                                     'water_jet_impulse': 8.0, 'haos_damage': 25,
                                     'wind_horizontal_scaled': 3.0, 'wind_vertical_impulse': 4.0},
              'objects': {}, 'sets': {}, 'fields': {}}
    variants = [(f'breakable_{index}', f'fielddestroy_n_{index}') for index in range(1,8)]
    for kind, stem in [*OBJECTS.values(), *variants]:
        records, paths = [], []
        for suffix in ['.nsbmd', '.nsbtx', '_data.bin']:
            source = 'Game/Gimmick/' + stem + suffix
            if (args.raw / source).is_file():
                prepared, record = prepare(args.raw, args.stage, source)
                paths.extend(prepared); records.append(record)
        converted = args.stage / stem
        converted.mkdir(exist_ok=True)
        run = subprocess.run([str(args.apicula), 'convert', '-f=glb', '--overwrite', *map(str, paths), '-o', str(converted)], capture_output=True, text=True)
        (converted/'conversion.log').write_text(run.stdout + run.stderr)
        if run.returncode:
            raise RuntimeError(f'Object conversion failed: {stem}')
        data, removed = remove_unmapped_animation_channels(embedded_glb(converted/(stem+'.glb')))
        target = destination/(stem+'.glb'); target.write_bytes(data)
        result['objects'][kind] = {'id': stem, 'path': 'res://assets/ds/field_objects/'+target.name,
                                  'source_files': records, 'sha256': hashlib.sha256(data).hexdigest(),
                                  'unsupported_animation_channels_removed': removed, 'srt': srt_entry(paths)}
    for source in sorted((args.raw/'Game/Gimmick/SetData').glob('SetData_*.bin')):
        decoded = parse_placements(decompress_lz10(source.read_bytes()))
        decoded.update(source_path=str(source.relative_to(args.raw)), source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        result['sets'][source.stem] = decoded
    for index, field in enumerate(FIELDS):
        sets = [name for name in result['sets'] if name.startswith(f'SetData_{index:02d}_')]
        if index == 0:
            sets = [name for name in sets if int(name.rsplit('_', 1)[1]) <= 2]
        result['fields']['ds_'+field] = sets
    tips = read_message_table(args.raw/'font/mes_tips_Dan.mes', args.raw)
    result['source_tips'] = {k: v for k,v in tips.items() if k != 'records'}
    result['source_tips']['records'] = [r for r in tips['records'] if r['index'] in [1,2,10,45,46,47]]
    path = destination/'manifest.json'
    path.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':'))+'\n')
    print(json.dumps({'objects':len(result['objects']), 'sets':len(result['sets']),
                      'records':sum(s['count'] for s in result['sets'].values()), 'manifest_bytes':path.stat().st_size}))


if __name__ == '__main__':
    main()
