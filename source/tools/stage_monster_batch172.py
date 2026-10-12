#!/usr/bin/env python3
"""Audit and stage the data-only Monster batch Workshop donor.

No TTS Lua or downloaded executable is run. OBJ state 1/2/3 is closed/toy/
monster respectively. Image size limits are explicit desktop adaptations;
source dimensions, SHA-256 and output pixel hashes remain in the manifests.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.request
import urllib.parse
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = Path('/workspace/bakugan-steam-0172')
CACHE = Path('/tmp/bakugan-monster-batch172')
ROOT = PROJECT / 'assets/monster_batch'
ATTRIBUTES = ['Pyrus', 'Aquos', 'Subterra', 'Haos', 'Darkus', 'Ventus']
ALIASES = {'Cancer': 'Terrorclaw', 'Battle Axe Vladitor': 'Battle Ax Vladitor'}


def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def relative(path):
    return 'res://' + path.relative_to(PROJECT).as_posix()


def resource_job(url, role):
    key = hashlib.sha256(url.encode()).hexdigest()[:20]
    return {'url': url, 'role': role, 'key': key}


def get_resource(job):
    role, key, url = job['role'], job['key'], job['url']
    extension = '.obj' if role == 'mesh' else '.webp'
    dest = ROOT / ('models_source' if role == 'mesh' else 'textures' if role == 'texture' else 'cards/faces') / (role + '_' + key + extension)
    # Downloaded OBJ remains in a non-exported research folder, not the game.
    if role == 'mesh':
        dest = SOURCE / 'mesh_cache' / ('mesh_' + key + '.obj')
    meta = SOURCE / 'staged_metadata' / (role + '_' + key + '.json')
    if meta.is_file():
        result = json.loads(meta.read_text())
        existing = PROJECT / result['path'].removeprefix('res://') if result['path'].startswith('res://') else Path(result['path'])
        if existing.is_file() and sha(existing) == result['sha256']:
            return result
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or not (parsed.hostname.endswith('steamusercontent.com') or parsed.hostname.endswith('akamaihd.net')):
        raise ValueError('Unexpected CDN URL: ' + url)
    raw = CACHE / (role + '_' + key)
    dest.parent.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(exist_ok=True)
    for attempt in range(3):
        try:
            if not raw.exists():
                part = raw.with_suffix('.partial')
                with urllib.request.urlopen(url, timeout=45) as response, part.open('wb') as stream:
                    size = 0
                    while chunk := response.read(1024 * 1024):
                        size += len(chunk)
                        if size > 32 * 1024 * 1024:
                            raise ValueError('Resource exceeds the 32 MiB audit limit')
                        stream.write(chunk)
                part.rename(raw)
            result = dict(job, source_sha256=sha(raw), source_bytes=raw.stat().st_size, path=relative(dest) if role != 'mesh' else str(dest))
            if role == 'mesh':
                header = raw.read_bytes()[:2048]
                if b'<!DOCTYPE' in header or not any(x in header for x in [b'v ', b'#', b'mtllib', b'o ']):
                    raise ValueError('Not OBJ text')
                dest.write_bytes(raw.read_bytes())
            else:
                image_source = raw
                is_video = raw.read_bytes()[:12][4:8] == b'ftyp'
                if is_video:
                    image_source = raw.with_suffix('.frame.png')
                    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-frames:v', '1', str(image_source)], check=True)
                    result['source_animated'] = True
                    result['animation_playback'] = False
                    if role == 'texture':
                        animation = dest.with_suffix('.ogv')
                        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-an', '-c:v', 'libtheora', '-q:v', '7', '-pix_fmt', 'yuv420p', str(animation)], check=True)
                        result['texture_animation'] = relative(animation)
                        result['animation_sha256'] = sha(animation)
                        result['animation_playback'] = True
                with Image.open(image_source) as original:
                    native = original.convert('RGBA')
                    result.update(source_dimensions=list(native.size), source_pixel_sha256=hashlib.sha256(native.tobytes()).hexdigest())
                    # 2048 texels is eight times a typical DS 256x256 skin;
                    # 1400x1900 keeps readable cards without >5GB of art.
                    limit = (2048, 2048) if role == 'texture' else (1400, 1900)
                    native.thumbnail(limit, Image.Resampling.LANCZOS)
                    native.save(dest, format='WEBP', lossless=True, method=4, exact=True)
                    with Image.open(dest) as check:
                        assert check.convert('RGBA').tobytes() == native.tobytes()
                    result.update(dimensions=list(native.size), pixel_sha256=hashlib.sha256(native.tobytes()).hexdigest(), transformation='aspect-preserving Lanczos downsample if over desktop limit; lossless WebP encoding', desktop_limit=list(limit))
            result.update(sha256=sha(dest), bytes=dest.stat().st_size, success=True)
            write(meta, result)
            if role != 'mesh' and image_source != raw:
                image_source.unlink()
            # The hashes and complete staged file make this raw cache redundant.
            raw.unlink()
            return result
        except Exception as error:
            if attempt == 2:
                return dict(job, success=False, error=str(error))
            time.sleep(0.5 * (attempt + 1))


def download():
    models = json.loads((SOURCE / 'replacement-models.json').read_text())
    cards = json.loads((SOURCE / 'new-cards.json').read_text())
    jobs = {}
    for model in models:
        for field, role in [('MeshURL', 'mesh'), ('DiffuseURL', 'texture')]:
            url = model['mesh'].get(field)
            if url:
                jobs.setdefault((url, role), resource_job(url, role))
    for card in cards:
        for field, role in [('face_url', 'card'), ('back_url', 'back')]:
            if card.get(field):
                jobs.setdefault((card[field], role), resource_job(card[field], role))
    results = []
    # Native faces load one at a time per worker; eight would use >1GB RAM.
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(get_resource, job) for job in jobs.values()]
        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            results.append(result)
            if i % 25 == 0 or not result['success']:
                print(i, '/', len(jobs), 'staged MB', round(sum(x.get('bytes', 0) for x in results) / 1e6), 'failures', sum(not x['success'] for x in results), result.get('error', ''), flush=True)
            if i % 25 == 0:
                write(SOURCE / 'staged-resources.json', results)
    write(SOURCE / 'staged-resources.json', results)
    assert all(x['success'] for x in results), 'Incomplete download; inspect staged-resources.json'
    print('DONE', len(results), 'resources', flush=True)


def prepare(finalize=False, models_only=False):
    resources = [json.loads(f.read_text()) for f in sorted((SOURCE / 'staged_metadata').glob('*.json'))]
    # WebP byte resources avoid duplicate editor texture caches.
    for resource in resources:
        if resource['role'] in (['texture'] if models_only else ['texture', 'card', 'back']) and resource['path'].endswith('.webp'):
            original = PROJECT / resource['path'].removeprefix('res://')
            destination = original.with_suffix('.webp.bin')
            original.rename(destination)
            sidecar = Path(str(original) + '.import')
            sidecar.unlink(missing_ok=True)
            resource['path'] = relative(destination)
            write(SOURCE / 'staged_metadata' / (resource['role'] + '_' + resource['key'] + '.json'), resource)
    by_url = {(x['url'], x['role']): x for x in resources if x['success']}
    old = json.loads((PROJECT / 'assets/imported/catalog.json').read_text())
    known = {x['name']: x for x in old['species'] + old.get('support', [])}
    entries, jobs = {}, {}
    skipped = []
    for item in json.loads((SOURCE / 'replacement-models.json').read_text()):
        match = re.fullmatch(r'((?:Pyrus|Aquos|Subterra|Haos|Darkus|Ventus)(?:/(?:Pyrus|Aquos|Subterra|Haos|Darkus|Ventus))*)\s+(.+?)\s*\((?:Closed|Stand)\)', item['name'].strip())
        if not match:
            skipped.append(item['name'])
            continue
        attributes, name = match.group(1).split('/'), match.group(2).strip()
        name = ALIASES.get(name, name)
        # The source has a single Preyas II closed/toy figure and separate
        # Angelo/Diablo monsters. Share only these two geometric forms.
        identities = ['Preyas II Angelo', 'Preyas II Diablo'] if name == 'Preyas II' and item['form'] != 'battle' else [name]
        mesh = by_url[(item['mesh']['MeshURL'], 'mesh')]
        image = by_url[(item['mesh']['DiffuseURL'], 'texture')]
        form = item['form']
        path = ROOT / 'models' / ('mesh_' + mesh['source_sha256'][:20] + '_' + form + '.glb')
        jobs.setdefault(str(path), {'input': mesh['path'], 'output': str(path), 'form': form, 'export_animations': False})
        provenance = {'workshop_id': '3696633172', 'mesh_url': mesh['url'], 'mesh_sha256': mesh['source_sha256'], 'texture_url': image['url'], 'texture_sha256': image['source_sha256'], 'source_name': item['name'], 'source_path': item['path'], 'source_attributes': attributes, 'source_state': {'ball': 1, 'toy': 2, 'battle': 3}[form], 'source_texture_dimensions': image['source_dimensions'], 'desktop_texture_dimensions': image['dimensions']}
        for identity in identities:
            if identity not in known:
                skipped.append(identity)
                continue
            entry = entries.setdefault(identity, {'name': identity, 'key': known[identity]['key'], 'forms': {}, 'source': {'workshop_id': '3696633172'}})
            definition = entry['forms'].setdefault(form, {'path': relative(path), 'native_attribute': attributes[0], 'texture_materials': ['Source_Diffuse'], 'double_sided': True, 'roughness': 0.65, 'native_geometry': True, 'native_texture_coordinates': True, 'animations': [], 'animation_roles': {}, 'source': provenance, 'variants': {}})
            for attribute in attributes:
                definition['variants'].setdefault(attribute, {'path': relative(path), 'texture': image['path'], 'source': provenance})
                if image.get('texture_animation'):
                    definition['variants'][attribute]['texture_animation'] = image['texture_animation']
    jobs_list = list(jobs.values())
    write(SOURCE / 'conversion-jobs.json', jobs_list)
    if finalize:
        assert all(Path(x['output']).is_file() for x in jobs_list)
        conversion = json.loads((SOURCE / 'conversion-report.json').read_text())
        assert not conversion['failures']
        for item in conversion['converted']:
            assert item['uv_layers'] and item['vertex_count']
        report = {'schema': 1, 'source': 'Monster batch', 'workshop_id': '3696633172', 'source_archive_sha256': sha(SOURCE / 'monster-batch.tts'), 'source_url': 'https://steamcommunity.com/sharedfiles/filedetails/?id=3696633172', 'species': sorted(entries.values(), key=lambda x: x['name']), 'support': [], 'textures': [x for x in resources if x['role'] == 'texture'], 'conversion': conversion, 'source_scripts_executed': False, 'static_geometry': True, 'new_skeleton_animations': 0, 'desktop_texture_limit': 2048, 'skipped_names': sorted(set(skipped)), 'counts': {'species': len(entries), 'converted_geometry': len(jobs), 'textures': sum(x['role'] == 'texture' for x in resources), 'forms': {f: sum(f in x['forms'] for x in entries.values()) for f in ['ball', 'toy', 'battle']}}}
        write(ROOT / 'model_manifest.json', report)
    if models_only:
        print(json.dumps({'models': len(jobs), 'species': len(entries), 'skipped': sorted(set(skipped))}), flush=True)
        return
    # Join duplicate references to retain the real taxonomy rather than the
    # incidental first occurrence inside a premade theme deck.
    merged = {}
    for card in json.loads((SOURCE / 'project-inventory.json').read_text())['cards']:
        key = (card['face_url'], card['cell'])
        aggregate = merged.setdefault(key, dict(card, labels=set(), aliases=set(), source_paths=[]))
        aggregate['labels'].update(card['labels'])
        aggregate['aliases'].add(card['name'])
        aggregate['source_paths'].append(card['path'])
    old_pixels = {x.get('pixel_sha256') for x in json.loads((PROJECT / 'assets/imported/source_cards.json').read_text())['cards']}
    cards = []
    for index, card in enumerate(merged.values()):
        image = by_url[(card['face_url'], 'card')]
        labels = card['labels']
        if 'Bakupod counters' in labels:
            kind, category = 'other', 'Bakupod counters / characteristics'
        elif labels & {'Attribute Normal Abilities', 'Generic Signature', 'Guardian Signatures', 'Fusion Abilities', 'Generic Normals', 'Guardian Normals'}:
            kind, category = 'ability', 'Abilities'
        elif labels & {'Attribute Gate Card', 'Command Card', 'Toy Command Card', 'Character Cards'}:
            kind, category = 'gate', 'Gate cards'
        else:
            kind, category = 'unclassified', 'Unclassified source resource'
        entry = {k: image[k] for k in ['path', 'sha256', 'pixel_sha256', 'source_pixel_sha256', 'source_sha256', 'source_dimensions', 'dimensions', 'transformation']}
        entry.update(index=index, key='mb_' + image['key'] + '_' + str(card['cell']), name=card['name'], raw_name=card['name'], aliases=sorted(card['aliases']), kind=kind, category=category, source_categories=sorted(labels), source_face_url=card['face_url'], source_back_url=card['back_url'], source_back_key='back_' + resource_job(card['back_url'], 'back')['key'], source_card_id=card['card_id'], source_cell=card['cell'], source_atlas_grid=[card['columns'], card['rows']], source_paths=card['source_paths'], source_description=card['description'], available=True, playable=False, rules_verified=False, source_animated=image.get('source_animated', False), animation_playback=False, exact_pixel_duplicate_of_previous=image['source_pixel_sha256'] in old_pixels)
        assert card['columns'] == card['rows'] == 1 and card['cell'] == 0
        cards.append(entry)
    backs = [dict(x, key='back_' + x['key'], available=True) for x in resources if x['role'] == 'back']
    ROOT.joinpath('cards/faces').mkdir(parents=True, exist_ok=True)
    # Pack image bytes directly: no second full-size editor texture cache.
    (ROOT / 'cards/faces/.gdignore').unlink(missing_ok=True)
    write(ROOT / 'cards/manifest.json', {'schema': 1, 'workshop_id': '3696633172', 'source_url': 'https://steamcommunity.com/sharedfiles/filedetails/?id=3696633172', 'source_archive_sha256': sha(SOURCE / 'monster-batch.tts'), 'cards': cards, 'backs': backs, 'source_scripts_executed': False, 'counts': {kind: sum(x['kind'] == kind for x in cards) for kind in ['gate', 'ability', 'other', 'unclassified']}, 'total': len(cards), 'desktop_face_limit': [1400, 1900], 'exact_pixel_duplicates_previous': sum(x['exact_pixel_duplicate_of_previous'] for x in cards)})
    print(json.dumps({'models': len(jobs), 'species': len(entries), 'cards': len(cards), 'skipped': sorted(set(skipped))}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--finalize', action='store_true')
    parser.add_argument('--models-only', action='store_true')
    args = parser.parse_args()
    if args.download:
        download()
    else:
        prepare(args.finalize, args.models_only)
