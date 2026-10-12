#!/usr/bin/env python3
"""Append missing Bakugan from a verified local Workshop inventory.

No network access is performed. Prepare copies original image bytes and writes
conversion jobs. Finalize verifies the GLBs, appends catalog entries and roster
indices, and leaves every previously shipped species declaration unchanged.
Support and trap entries form a separate gallery collection, excluded from
playable roster indices and team slots.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from stage_source_assets import digest, image_suffix


ATTRIBUTES = ('Pyrus', 'Aquos', 'Subterra', 'Haos', 'Darkus', 'Ventus')
FORMS = ('ball', 'toy', 'battle')


def resource(project: Path, path: Path) -> str:
    return 'res://' + path.relative_to(project).as_posix()


def safe_key(value: str) -> str:
    if not re.fullmatch(r'[a-z0-9_]+', value):
        raise ValueError(f'Invalid canonical key: {value!r}')
    return value


def checked_file(value: str) -> Path:
    path = Path(value).resolve()
    if not path.is_file() or path.stat().st_size == 0:
        raise FileNotFoundError(path)
    return path


def normalize_inventory(inventory: dict, download_jobs: Path) -> dict:
    """Accept the audit's per-attribute forms without losing source availability."""
    jobs = {item['key']: item for item in json.loads(download_jobs.read_text(encoding='utf-8'))}
    result = {key: value for key, value in inventory.items() if key != 'species'}
    result['species'] = []
    for original in inventory['species']:
        if 'group' not in original:
            result['species'].append(original)
            continue
        entry = {
            'key': original['key'], 'name': original['name'],
            'source': original['source'],
            'classification': 'bakugan' if original['group'] == 'creature' else original['group'],
            'forms': {},
        }
        preferred = 'Pyrus'
        if original['forms'].get('ball'):
            attributes = original['forms']['ball']
            preferred = 'Pyrus' if 'Pyrus' in attributes else next(iter(attributes))
        for form, source_variants in original['forms'].items():
            native_attribute = preferred if preferred in source_variants else next(iter(source_variants))
            native = source_variants[native_attribute]
            definition = {
                'mesh_key': native['mesh_job'],
                'mesh_path': jobs[native['mesh_job']]['path'],
                'mesh_url': native['mesh_url'],
                'native_attribute': native_attribute,
                'variants': {},
            }
            for attribute, source_variant in source_variants.items():
                definition['variants'][attribute] = {
                    'texture_key': source_variant['texture_job'],
                    'texture_path': jobs[source_variant['texture_job']]['path'],
                    'texture_url': source_variant['texture_url'],
                    'source_name': source_variant['name'],
                    'source_path': source_variant['source_path'],
                    'source_transform': source_variant.get('transform', {}),
                    'source_attribute_prefix': source_variant.get('source_attribute_prefix', attribute),
                    'mesh_key': source_variant['mesh_job'],
                    'mesh_path': jobs[source_variant['mesh_job']]['path'],
                    'mesh_url': source_variant['mesh_url'],
                }
            entry['forms'][form] = definition
        result['species'].append(entry)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--jobs', type=Path, required=True)
    parser.add_argument('--download-jobs', type=Path, help='Required for the per-attribute audit inventory')
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--finalize', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
    if any('group' in entry for entry in inventory['species']):
        if not args.download_jobs:
            parser.error('--download-jobs is required for this audit inventory')
        inventory = normalize_inventory(inventory, args.download_jobs)
    catalog_path = project / 'assets/imported/catalog.json'
    original_bytes = catalog_path.read_bytes()
    catalog = json.loads(original_bytes)
    before = json.loads(original_bytes)
    original_keys = {entry['key'] for entry in catalog['species'] + catalog.get('support', [])}
    roster_path = project / 'scripts/roster.gd'
    roster = roster_path.read_text(encoding='utf-8')
    roster_keys = re.findall(r'\{"id": "([a-z0-9_]+)"', roster)
    known = original_keys | set(roster_keys)
    workshop_id = str(inventory.get('workshop_id', '3412700725'))
    model_folder = project / 'assets/imported/models'
    texture_folder = project / 'assets/imported/textures'
    model_folder.mkdir(parents=True, exist_ok=True)
    texture_folder.mkdir(parents=True, exist_ok=True)
    jobs: dict[tuple[str, str], dict] = {}
    staged: dict[str, dict] = {}
    entries = []
    support_entries = []
    skipped = []

    def geometry(source: dict, form: str) -> tuple[str, dict]:
        source_mesh = checked_file(source['mesh_path'])
        key = safe_key(source['mesh_key'])
        output = model_folder / f's08_{key}_{form}.glb'
        identity = (key, form)
        conversion = {'input': str(source_mesh), 'output': str(output), 'form': form}
        for field in ('source_forward', 'source_up', 'rotation_degrees', 'roughness',
                      'target_height', 'maximum_width', 'maximum_depth', 'ball_radius'):
            if field in source:
                conversion[field] = source[field]
        if identity in jobs and jobs[identity] != conversion:
            raise ValueError(f'Conflicting geometry key: {identity}')
        jobs[identity] = conversion
        if args.finalize:
            checked_file(str(output))
            if output.read_bytes()[:4] != b'glTF':
                raise ValueError(f'Invalid converted GLB: {output}')
        return resource(project, output), {
            'workshop_id': workshop_id,
            'mesh_url': source['mesh_url'],
            'mesh_sha256': digest(source_mesh),
        }

    def texture(source: dict) -> tuple[str, dict]:
        source_texture = checked_file(source['texture_path'])
        key = safe_key(source['texture_key'])
        native_hash = digest(source_texture)
        destination = texture_folder / f's08_{key}{image_suffix(source_texture)}'
        if destination.exists() and digest(destination) != native_hash:
            raise ValueError(f'Existing staged texture has different bytes: {destination}')
        if not destination.exists():
            shutil.copy2(source_texture, destination)
        if digest(destination) != native_hash:
            raise ValueError(f'Staged image changed bytes: {destination}')
        staged[str(source_texture)] = {'path': str(destination), 'sha256': native_hash}
        return resource(project, destination), {
            'workshop_id': workshop_id,
            'texture_url': source['texture_url'],
            'texture_sha256': native_hash,
            'source_name': source.get('source_name', ''),
            'source_path': source.get('source_path', ''),
            'source_transform': source.get('source_transform', {}),
            'source_attribute_prefix': source.get('source_attribute_prefix', ''),
        }

    for source_entry in sorted(inventory['species'], key=lambda item: item['key']):
        key = safe_key(source_entry['key'])
        classification = source_entry.get('classification', 'bakugan')
        if classification not in {'bakugan', 'trap', 'support'} or key in known:
            skipped.append({'key': key, 'reason': 'already shipped' if key in known else classification})
            continue
        known.add(key)
        entry = {
            'key': key, 'name': source_entry['name'],
            'source': source_entry.get('source', inventory.get('source', f'Steam Workshop {workshop_id}')),
            'classification': classification, 'introduced_version': '0.8', 'forms': {},
        }
        if source_entry.get('aliases'):
            entry['aliases'] = source_entry['aliases']
        for form in FORMS:
            source_form = source_entry['forms'].get(form)
            if not source_form:
                continue
            path, mesh_source = geometry(source_form, form)
            source_variants = source_form.get('variants', {})
            if not source_variants:
                raise ValueError(f'{key} {form} has no actual native image variants')
            native_attribute = source_form.get('native_attribute', next(iter(source_variants)))
            if native_attribute not in source_variants:
                raise ValueError(f'{key} {form} native attribute is not a source variant')
            definition = {
                'path': path, 'native_attribute': native_attribute,
                'texture_materials': ['Source_Diffuse'], 'double_sided': True,
                'roughness': float(source_form.get('roughness', 0.65)),
                'source': mesh_source, 'variants': {},
            }
            for attribute, source_variant in source_variants.items():
                if attribute not in ATTRIBUTES:
                    raise ValueError(f'{key} {form} has an unsupported attribute {attribute}')
                texture_path, texture_source = texture(source_variant)
                variant = {'texture': texture_path, 'source': {**mesh_source, **texture_source}}
                if source_variant.get('mesh_path'):
                    variant_path, variant_mesh_source = geometry(source_variant, form)
                    variant['source'].update(variant_mesh_source)
                    if variant_path != path:
                        variant['path'] = variant_path
                definition['variants'][attribute] = variant
            entry['forms'][form] = definition
        if not entry['forms']:
            raise ValueError(f'{key} has no imported forms')
        (entries if classification == 'bakugan' else support_entries).append(entry)

    args.jobs.parent.mkdir(parents=True, exist_ok=True)
    args.jobs.write_text(json.dumps(list(jobs.values()), indent=2) + '\n', encoding='utf-8')
    if args.finalize:
        catalog['species'].extend(entries)
        previous_support = before.get('support', [])
        catalog.setdefault('support', []).extend(support_entries)
        if catalog['species'][:len(before['species'])] != before['species']:
            raise AssertionError('Previously shipped catalog declarations changed')
        if catalog['support'][:len(previous_support)] != previous_support:
            raise AssertionError('Previously shipped support declarations changed')
        history = catalog.setdefault('append_sources', [])
        if entries or support_entries:
            history.append({'version': '0.8', 'workshop_id': workshop_id,
                            'source': inventory.get('source', ''),
                            'inventory_sha256': digest(args.inventory),
                            'species_keys': [entry['key'] for entry in entries],
                            'support_keys': [entry['key'] for entry in support_entries]})
        append = ''.join('\t{"id": "%s", "name": "%s", "g": %d},\n' % (
            entry['key'], entry['name'], 300 + (index % 7) * 10
        ) for index, entry in enumerate(entries))
        if append:
            marker = ']\nconst ATTRIBUTES = '
            if roster.count(marker) != 1:
                raise ValueError('Cannot identify append-only roster insertion point')
            roster = roster.replace(marker, '\t# 0.8 additions; native source skins only, demo G balance.\n' + append + marker, 1)
            if re.findall(r'\{"id": "([a-z0-9_]+)"', roster)[:len(roster_keys)] != roster_keys:
                raise AssertionError('Existing roster save indices changed')
        catalog_path.write_text(json.dumps(catalog, indent=2) + '\n', encoding='utf-8')
        roster_path.write_text(roster, encoding='utf-8')
    report = {
        'version': '0.8', 'workshop_id': workshop_id,
        'previous_species': len(before['species']), 'added_species': len(entries),
        'added_keys': [entry['key'] for entry in entries],
        'added_forms': sum(len(entry['forms']) for entry in entries),
        'added_support': len(support_entries),
        'support_keys': [entry['key'] for entry in support_entries],
        'support_forms': sum(len(entry['forms']) for entry in support_entries),
        'conversions': len(jobs), 'native_textures': len(staged),
        'catalog_finalized': args.finalize, 'skipped': skipped,
        'previous_catalog_sha256': hashlib.sha256(original_bytes).hexdigest(),
        'previous_entries_unchanged': True,
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
