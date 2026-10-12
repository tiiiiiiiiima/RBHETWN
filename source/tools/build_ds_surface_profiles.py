#!/usr/bin/env python3
"""Compile CPU-skinned source-rest DS throw triangles into static PC surfaces.

Use the companion inspect_ds_throw_surfaces.gd report. The profile preserves
world-space source geometry and its provenance. This is analytic PC collision,
not the original Nintendo DS physics, animated hazards, or material tracks.
"""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('triangles', type=Path)
    parser.add_argument('--manifest', type=Path, default=Path('assets/ds/arenas/arena_manifest.json'))
    parser.add_argument('--output', type=Path, default=Path('assets/ds/arenas/throw_surface_profiles.json'))
    args = parser.parse_args()
    source = json.loads(args.triangles.read_text())
    manifest = json.loads(args.manifest.read_text())
    output = {'schema': 1, 'source_rom_sha256': manifest['source']['rom_sha256'],
              'adaptation': 'CPU-skinned native rest triangles. PC static sphere collision and shared gate grid; no native DS collision code or moving arena gimmicks.',
              'frozen_source_animation': True, 'sphere_radius': 0.44, 'groups': {}}
    for group_id, triangles in source.items():
        if not group_id.endswith('_throw'):
            continue
        compiled = []
        components = {}
        area = manifest['groups'][group_id].get('play_area', {})
        bounds = area.get('half_extents', [18,18])
        ceiling = area.get('collision_ceiling', 40)
        for triangle in triangles:
            vertices = [triangle[k] for k in ('a', 'b', 'c')]
            low = [min(p[i] for p in vertices) for i in range(3)]
            high = [max(p[i] for p in vertices) for i in range(3)]
            # PC spheres are confined to this local floor. Remote source sky
            # and architecture have no possible contact with the throw path.
            if high[0] < -bounds[0]-2 or low[0] > bounds[0]+2 or high[2] < -bounds[1]-2 or low[2] > bounds[1]+2 or high[1] < -12 or low[1] > ceiling:
                continue
            compiled.append([round(value, 6) for p in vertices for value in p])
            components[triangle['component']] = components.get(triangle['component'], 0) + 1
        output['groups'][group_id] = {
            'center_bounds': bounds,
            'source_components': [{'id': c['id'], 'path': c['path'], 'sha256': c['sha256']} for c in manifest['groups'][group_id]['components']],
            'source_rest_triangles': len(triangles), 'local_collision_triangles': len(compiled),
            'triangles_by_component': components, 'triangles': compiled}
    args.output.write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps({'groups': len(output['groups']), 'collision_triangles': sum(len(g['triangles']) for g in output['groups'].values()), 'bytes': args.output.stat().st_size, 'sha256': hashlib.sha256(args.output.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
