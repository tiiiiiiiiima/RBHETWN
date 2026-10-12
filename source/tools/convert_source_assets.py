#!/usr/bin/env python3
"""Convert locally downloaded source meshes into normalized, UV-preserving GLBs.

Run once for a batch, inside Blender (no network access is performed):
    blender --background --python tools/convert_source_assets.py -- --jobs jobs.json

jobs.json contains a list, or {"jobs": [...]}. Each job has input, output,
form (ball/toy/battle), and optional texture, source_up, source_forward,
rotation_degrees, target_height, maximum_width, maximum_depth, ball_radius.
Output geometry uses one neutral Source_Diffuse material unless
preserve_materials=true. Original attribute textures remain separate files and
are selected at runtime; geometry is not duplicated for each colour.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jobs', type=Path, required=True)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    command = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    return parser.parse_args(command)


def jobs_from(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding='utf-8'))
    jobs = data.get('jobs', []) if isinstance(data, dict) else data
    if not isinstance(jobs, list):
        raise ValueError('Jobs must be a list')
    for job in jobs:
        if not isinstance(job, dict) or not {'input', 'output', 'form'} <= job.keys():
            raise ValueError('Each job needs input, output and form')
        if job['form'] not in {'ball', 'toy', 'battle'}:
            raise ValueError(f"Invalid form: {job['form']}")
        if not Path(job['input']).is_file():
            raise FileNotFoundError(job['input'])
        if Path(job['output']).suffix.lower() != '.glb':
            raise ValueError('Output must have .glb extension')
        if job.get('texture') and not Path(job['texture']).is_file():
            raise FileNotFoundError(job['texture'])
    return jobs


def import_mesh(bpy, job: dict) -> None:
    path = Path(job['input']).resolve()
    extension = path.suffix.lower()
    if extension == '.obj':
        bpy.ops.wm.obj_import(
            filepath=str(path),
            forward_axis=job.get('source_forward', 'NEGATIVE_Z'),
            up_axis=job.get('source_up', 'Y'),
            validate_meshes=True,
        )
    elif extension in {'.glb', '.gltf'}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif extension == '.fbx':
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif extension == '.dae':
        bpy.ops.wm.collada_import(filepath=str(path))
    elif extension == '.blend':
        with bpy.data.libraries.load(str(path), link=False) as (source, target):
            target.objects = source.objects
        for obj in target.objects:
            if obj is not None:
                bpy.context.collection.objects.link(obj)
    else:
        raise ValueError(f'Unsupported mesh extension: {extension}')


def convert(bpy, Vector, job: dict) -> dict:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # Long batches should not retain data from previously converted objects.
    for collection in [bpy.data.meshes, bpy.data.materials, bpy.data.images]:
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)
    import_mesh(bpy, job)
    objects = [obj for obj in bpy.context.scene.objects if obj.type not in {'LIGHT', 'CAMERA'}]
    meshes = [obj for obj in objects if obj.type == 'MESH' and len(obj.data.vertices)]
    if not meshes:
        raise ValueError(f"No mesh geometry in {job['input']}")
    root = bpy.data.objects.new('SourceModel', None)
    bpy.context.collection.objects.link(root)
    for obj in objects:
        if obj.parent is None:
            transform = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = transform
    rotation = job.get('rotation_degrees', [0, 0, 0])
    root.rotation_euler = [math.radians(float(angle)) for angle in rotation]
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    if not all(math.isfinite(component) and component > 1e-8 for component in size):
        raise ValueError(f"Invalid or flat mesh bounds: {job['input']}, {tuple(size)}")
    if job['form'] == 'ball':
        scale = 2.0 * float(job.get('ball_radius', 0.38)) / max(size)
        offset = -(minimum + maximum) * 0.5
    else:
        battle = job['form'] == 'battle'
        scale = min(
            float(job.get('target_height', 2.6 if battle else 2.0)) / size.z,
            float(job.get('maximum_width', 3.2 if battle else 2.7)) / size.x,
            float(job.get('maximum_depth', 3.4 if battle else 2.7)) / size.y,
        )
        offset = Vector((-(minimum.x + maximum.x) * 0.5, -(minimum.y + maximum.y) * 0.5, -minimum.z))
    root.scale *= scale
    root.location = offset * scale
    bpy.context.view_layer.update()

    if not job.get('preserve_materials', False):
        material = bpy.data.materials.new('Source_Diffuse')
        material.use_nodes = True
        material.diffuse_color = (1, 1, 1, 1)
        material.use_backface_culling = False
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (1, 1, 1, 1)
        shader.inputs['Metallic'].default_value = 0
        shader.inputs['Roughness'].default_value = float(job.get('roughness', 0.65))
        if job.get('texture'):
            image = bpy.data.images.load(str(Path(job['texture']).resolve()), check_existing=True)
            image.colorspace_settings.name = 'sRGB'
            node = material.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            material.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])
            if job.get('use_texture_alpha', False):
                material.node_tree.links.new(node.outputs['Alpha'], shader.inputs['Alpha'])
        for obj in meshes:
            obj.data.materials.clear()
            obj.data.materials.append(material)
            for polygon in obj.data.polygons:
                polygon.material_index = 0
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects + [root]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    destination = Path(job['output']).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(destination), export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_materials='EXPORT',
        export_animations=bool(job.get('export_animations', True)), export_extras=True,
    )
    return {
        'input': str(Path(job['input']).resolve()), 'output': str(destination),
        'form': job['form'], 'mesh_count': len(meshes),
        'vertex_count': sum(len(obj.data.vertices) for obj in meshes),
        'source_size_blender': list(size), 'normalization_scale': scale,
        'normalized_size_blender': [float(component * scale) for component in size],
        'uv_layers': sum(len(obj.data.uv_layers) for obj in meshes),
        'bytes': destination.stat().st_size,
    }


def main() -> None:
    args = arguments()
    jobs = jobs_from(args.jobs)
    if args.dry_run:
        print(json.dumps({'jobs': len(jobs), 'valid': True}))
        return
    import bpy
    from mathutils import Vector
    results = []
    failures = []
    for index, job in enumerate(jobs):
        try:
            result = convert(bpy, Vector, job)
            results.append(result)
            print(f"Converted {index + 1}/{len(jobs)}: {job['output']}", flush=True)
        except Exception as error:
            failures.append({'input': job['input'], 'output': job['output'], 'error': str(error)})
            print(f"FAILED {job['input']}: {error}", flush=True)
    report = {'converted': results, 'failures': failures}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'converted': len(results), 'failures': len(failures)}), flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
