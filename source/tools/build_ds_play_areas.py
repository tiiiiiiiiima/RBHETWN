#!/usr/bin/env python3
"""Bound desktop DS traversal by native floors and decoded active SetData.

The floor shape and object coordinates are source data. The padding and
collision ceiling are desktop broad-phase safeguards, not DS physics values.
"""
import argparse
import json
import math
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=Path('assets/ds/arenas/arena_manifest.json'))
    parser.add_argument('--objects', type=Path, default=Path('assets/ds/field_objects/manifest.json'))
    parser.add_argument('--triangles', type=Path, help='Measured world-space source-rest triangle report')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    objects = json.loads(args.objects.read_text())
    geometry = json.loads(args.triangles.read_text()) if args.triangles else {}
    results = {}
    for theme, layouts in objects['fields'].items():
        group = manifest['groups'][theme.removeprefix('ds_')+'_throw']
        fit = group['pc_fit']
        scale, offset = fit['uniform_scale'], fit['source_offset']
        floor = fit['world_floor_bounds']
        half = [max(abs(floor['min'][axis]), abs(floor['max'][axis])) for axis in (0,2)]
        height = 12.0
        for layout in layouts:
            for record in objects['sets'][layout]['records']:
                if record['kind'] not in objects['objects']:
                    continue
                point = [(record['position'][i]+offset[i])*scale for i in range(3)]
                radius = math.sqrt(sum(v*v for v in record['extent']))*scale
                half = [max(half[i], abs(point[axis])+radius) for i,axis in enumerate((0,2))]
                height = max(height, point[1]+radius+8.0)
        floor_triangles = 0
        for triangle in geometry.get(theme.removeprefix('ds_')+'_throw', []):
            a,b,c = [triangle[k] for k in 'abc']
            u,v = [[p[i]-a[i] for i in range(3)] for p in (b,c)]
            normal = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            length = math.sqrt(sum(v*v for v in normal))
            center = [(a[i]+b[i]+c[i])/3 for i in range(3)]
            near_field = 24.0*fit['target_short_floor_span']/18.0
            if length<1e-7 or abs(normal[1])/length<0.8 or not -.4<=center[1]<=height:
                continue
            if max(abs(center[0]),abs(center[2]))>near_field:
                continue
            for i,axis in enumerate((0,2)):
                half[i] = max(half[i],min(near_field,max(abs(p[axis]) for p in (a,b,c))))
            floor_triangles += 1
        group['play_area'] = {
            'half_extents': [round(v+2.0,6) for v in half],
            'collision_ceiling': round(height,6),
            'basis': 'Measured native floor, near-field walkable rest triangles and known SetData objects, with desktop safety padding.',
            'measured_walkable_triangles': floor_triangles,
            'source_layouts': layouts,
            'not_original_ds_boundary': True,
        }
        results[theme] = group['play_area']
    args.manifest.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(results,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
