#!/usr/bin/env python3
"""Archive complete native source assets, code and documentation for release 0.10.

The project assets are shipped unchanged, including native PNG/JPEG textures,
converted GLB geometry and JSON provenance catalogs. Godot import caches,
runtime builds, Python bytecode and external /tmp download caches are excluded.
No network requests or Godot imports are performed by this builder.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


RELEASE_VERSION = '0.10'
EXCLUDED_DIRECTORIES = {'.git', '.godot', 'builds', '__pycache__', '.pytest_cache'}
REQUIRED_FILES = (
    'project.godot', 'export_presets.cfg', 'README.md',
    'THIRD-PARTY-LICENSES.txt', 'assets/FONT-LICENSE.txt',
    'assets/imported/catalog.json', 'assets/imported/cards.json',
    'assets/imported/source_cards.json',
    'assets/imported/canonical_profiles.json',
    'assets/imported/trap_profiles.json',
    'assets/imported/arenas/source_manifest.json',
    'docs/ASSET-SOURCES-0.7.md', 'docs/ASSET-SOURCES-0.8.md',
    'docs/RELEASE-0.9.md', 'docs/RULES-COMPARISON.md',
    'docs/BLOXUGAN-COMPARISON-0.8.md',
    'docs/ANIME-DUEL-API-0.8.md', 'docs/CARD-LIBRARY-0.8.md',
    'docs/ANIME-DUEL-API-0.9.md', 'docs/CANONICAL-PROFILES-0.9.md',
    'docs/TRAPS-0.9.md',
    'docs/RELEASE-0.10.md', 'docs/ASSET-SOURCES-0.10.md',
    'docs/DS-HUD-ASSETS.md', 'docs/DS-ARENAS.md',
    'docs/DS-MODEL-CONVERSION.md', 'docs/DS-IMPORT-NOTES.md',
    'assets/ds/ui_manifest.json', 'assets/ds/messages.json',
    'assets/ds/models/model_manifest.json', 'assets/ds/arenas/arena_manifest.json',
    'docs/WII-SOURCES.md', 'docs/TABLETOP-SOURCES.md',
    'docs/FIDELITY.md', 'docs/VALIDATION.md', 'docs/CHANGELOG.md',
)


def collect_source_files(project: Path) -> list[Path]:
    files = []
    for entry in sorted(project.rglob('*')):
        relative = entry.relative_to(project)
        if any(part in EXCLUDED_DIRECTORIES for part in relative.parts):
            continue
        if entry.is_symlink():
            raise ValueError(f'Source snapshot must contain native files, not symlinks: {relative}')
        if entry.is_file() and entry.suffix not in {'.pyc', '.pyo'}:
            files.append(entry)
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='Inspect the manifest without writing a ZIP')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    for relative in REQUIRED_FILES:
        if not (project / relative).is_file():
            raise SystemExit(f'Required source file is missing: {relative}')
    files = collect_source_files(project)
    counts = {
        'native_images': sum(p.suffix.lower() in {'.png', '.jpg', '.jpeg'} for p in files),
        'glb_models': sum(p.suffix.lower() == '.glb' for p in files),
        'json_catalogs': sum(p.suffix.lower() == '.json' for p in files),
    }
    if not counts['native_images'] or not counts['glb_models']:
        raise SystemExit('Native images and converted GLB models are required in the source snapshot')
    package_name = f'Bakugan-{RELEASE_VERSION}-Source'
    destination = project / 'builds' / f'{package_name}.zip'
    summary = {
        'archive': str(destination), 'version': RELEASE_VERSION,
        'source_files': len(files), 'source_bytes': sum(p.stat().st_size for p in files),
        'asset_counts': counts, 'dry_run': args.dry_run,
    }
    if not args.dry_run:
        runtime_notices = project / 'builds' / f'Bakugan-{RELEASE_VERSION}-Pack'
        if not runtime_notices.is_dir():
            runtime_notices = project / 'builds' / f'Bakugan-{RELEASE_VERSION}-Linux'
        engine_notices = ('GODOT-LICENSE.txt',)
        for notice in engine_notices:
            if not (runtime_notices / notice).is_file():
                raise SystemExit(f'Build the game pack first to obtain {notice}')
        destination.parent.mkdir(parents=True, exist_ok=True)
        partial = destination.with_suffix('.zip.partial')
        try:
            with zipfile.ZipFile(partial, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for entry in files:
                    archive.write(entry, Path(package_name) / entry.relative_to(project))
                for notice in engine_notices:
                    archive.write(runtime_notices / notice, Path(package_name) / notice)
            partial.replace(destination)
        finally:
            partial.unlink(missing_ok=True)
        destination.chmod(0o644)
        summary['bytes'] = destination.stat().st_size
        with destination.open('rb') as archive:
            summary['sha256'] = hashlib.file_digest(archive, 'sha256').hexdigest()
        summary['engine_notices'] = list(engine_notices)
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
