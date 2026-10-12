#!/usr/bin/env python3
"""Stage the downloaded Workshop board and panorama without changing images.

Run in Blender: blender --background --python tools/stage_source_arena08.py
The original mesh UVs remain intact; the manifest records the material UV
scale used at runtime to display the field image once rather than 44 × 16.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    import bpy
    from mathutils import Vector

    project = Path(__file__).resolve().parents[1]
    research = Path('/tmp/bakugan08-research')
    downloads = research / 'downloads'
    candidates = json.loads((research / 'source-arena-candidates.json').read_text())
    board, panorama = candidates
    source_mesh = downloads / (board['mesh_job'] + '.obj')
    destination = project / 'assets' / 'imported' / 'arenas'
    destination.mkdir(parents=True, exist_ok=True)
    mesh_path = destination / 'anime_board.glb'
    textures = []
    for descriptor, filename in [(board, 'anime_board.png'), (panorama, 'anime_sky.png')]:
        source = downloads / (descriptor['texture_job'] + '.image')
        if source.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f'Expected the original PNG: {source}')
        target = destination / filename
        shutil.copyfile(source, target)
        textures.append({'path': 'res://' + str(target.relative_to(project)),
                         'source_url': descriptor['texture_url'],
                         'source_sha256': sha256(source), 'sha256': sha256(target),
                         'bytes': target.stat().st_size})

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.wm.obj_import(filepath=str(source_mesh), forward_axis='NEGATIVE_Z', up_axis='Y')
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if len(meshes) != 1:
        raise ValueError(f'Expected one source board mesh, got {len(meshes)}')
    root = bpy.data.objects.new('SourceBoard', None)
    bpy.context.collection.objects.link(root)
    for obj in meshes:
        transform = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = transform
    root.rotation_euler.z = math.pi  # Source Transform.rotY = 180 degrees.
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    target_size = Vector((12.7, 10.8, 0.25))
    scale = Vector(tuple(target_size[axis] / size[axis] for axis in range(3)))
    root.scale = scale
    root.location = Vector((-(minimum.x + maximum.x) * 0.5 * scale.x,
                            -(minimum.y + maximum.y) * 0.5 * scale.y,
                            -maximum.z * scale.z))
    material = bpy.data.materials.new('Source_Board_Diffuse')
    material.use_nodes = True
    material.diffuse_color = (1, 1, 1, 1)
    material.use_backface_culling = False
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (1, 1, 1, 1)
    shader.inputs['Roughness'].default_value = 1
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes + [root]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(mesh_path), export_format='GLB', use_selection=True,
                             export_apply=True, export_yup=True, export_materials='EXPORT',
                             export_animations=False, export_extras=True)
    manifest = {
        'schema': 1, 'workshop_id': '3412700725',
        'workshop_url': 'https://steamcommunity.com/sharedfiles/filedetails/?id=3412700725',
        'scope': 'One source table board and one source sky panorama; not an original Wii level.',
        'board': {
            'path': 'res://assets/imported/arenas/anime_board.glb',
            'texture': textures[0], 'source_mesh_url': board['mesh_url'],
            'source_mesh_sha256': sha256(source_mesh), 'sha256': sha256(mesh_path),
            'source_transform': board['transform'], 'source_tint': board['color_diffuse'],
            'source_dimensions': [24, 1, 12], 'dimensions': [12.7, 0.25, 10.8],
            'surface_y': 0, 'source_uv_preserved': True, 'material_uv_scale': [1 / 44, 1 / 16],
            'adaptation': 'Board centered and fitted to the existing rolling field; native UVs retained in GLB. Material UV scale displays one full field image instead of 44 by 16 source repeats.',
        },
        'sky': textures[1],
    }
    (destination / 'source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'board': str(mesh_path), 'texture_bytes_preserved': True,
                      'mesh_vertices': sum(len(obj.data.vertices) for obj in meshes),
                      'uv_layers': sum(len(obj.data.uv_layers) for obj in meshes),
                      'dimensions': manifest['board']['dimensions']}))


if __name__ == '__main__':
    main()
