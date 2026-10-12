#!/usr/bin/env python3
"""Stage verified local TTS textures and prepare/finalize the imported catalog.

This tool performs no downloads. Prepare writes Blender conversion jobs and
copies native image bytes; finalize writes catalog.json only after every
referenced converted mesh and texture exists. The original Workshop geometry
and textures retain their source URLs and SHA-256 in the manifest.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def image_suffix(path: Path) -> str:
    data = path.read_bytes()[:16]
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return '.png'
    if data.startswith(b'\xff\xd8\xff'):
        return '.jpg'
    if data.startswith(b'RIFF') and data[8:12] == b'WEBP':
        return '.webp'
    raise ValueError(f'Not a recognized native image: {path}')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--jobs', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--finalize', action='store_true')
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
    project = args.project.resolve()
    assets = project / 'assets' / 'imported'
    models = assets / 'models'
    textures = assets / 'textures'
    models.mkdir(parents=True, exist_ok=True)
    textures.mkdir(parents=True, exist_ok=True)
    entries = []
    jobs = {}
    copied = {}
    source_geometry = {}
    for source_entry in inventory['species']:
        entry = {key: source_entry[key] for key in ['key', 'name', 'source']}
        entry['forms'] = {}
        for form, source_form in source_entry['forms'].items():
            source_mesh = Path(source_form['mesh_path'])
            if not source_mesh.is_file() or source_mesh.stat().st_size == 0:
                raise FileNotFoundError(f"Missing downloaded mesh: {source_mesh}")
            output = models / (source_form['mesh_key'] + '_' + form + '.glb')
            relative_mesh = 'res://' + output.relative_to(project).as_posix()
            key = (source_form['mesh_key'], form)
            if key not in jobs:
                jobs[key] = {'input': str(source_mesh), 'output': str(output), 'form': form}
            if str(source_mesh) not in source_geometry:
                source_geometry[str(source_mesh)] = digest(source_mesh)
            definition = {
                'path': relative_mesh,
                'native_attribute': 'Pyrus',
                'texture_materials': ['Source_Diffuse'],
                'double_sided': True,
                'roughness': 0.65,
                'source': {
                    'workshop_id': '2480698294',
                    'mesh_url': source_form['mesh_url'],
                    'mesh_sha256': source_geometry[str(source_mesh)],
                },
                'variants': {},
            }
            if args.finalize and (not output.is_file() or output.stat().st_size < 100):
                raise FileNotFoundError(f"Missing converted GLB: {output}")
            for attribute, variant in source_form['variants'].items():
                source_texture = Path(variant['texture_path'])
                if not source_texture.is_file():
                    raise FileNotFoundError(f"Missing downloaded texture: {source_texture}")
                if str(source_texture) not in copied:
                    destination = textures / (variant['texture_key'] + image_suffix(source_texture))
                    shutil.copy2(source_texture, destination)
                    native_sha = digest(source_texture)
                    if digest(destination) != native_sha:
                        raise ValueError(f"Staged image changed bytes: {destination}")
                    copied[str(source_texture)] = {'destination': destination, 'sha256': native_sha}
                staged = copied[str(source_texture)]
                definition['variants'][attribute] = {
                    'texture': 'res://' + staged['destination'].relative_to(project).as_posix(),
                    'source': {
                        'workshop_id': '2480698294',
                        'mesh_url': source_form['mesh_url'],
                        'mesh_sha256': source_geometry[str(source_mesh)],
                        'texture_url': variant['texture_url'],
                        'texture_sha256': staged['sha256'],
                        'source_name': variant['source_name'],
                        'source_path': variant['source_path'],
                    },
                }
            entry['forms'][form] = definition
        entries.append(entry)
    report = {
        'schema': 1,
        'source': inventory.get('source', 'Steam Workshop 2480698294'),
        'source_inventory_sha256': digest(args.inventory),
        'species': entries,
    }
    args.jobs.parent.mkdir(parents=True, exist_ok=True)
    args.jobs.write_text(json.dumps(list(jobs.values()), indent=2), encoding='utf-8')
    if args.finalize:
        (assets / 'catalog.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({
        'species': len(entries), 'forms': sum(len(entry['forms']) for entry in entries),
        'unique_conversions': len(jobs), 'unique_native_textures': len(copied),
        'catalog_finalized': args.finalize,
    }))


if __name__ == '__main__':
    main()
