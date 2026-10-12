#!/usr/bin/env python3
"""Configure imported creature skins for GPU compression and mipmaps.

Run after the first Godot editor import, then import the project again. Only
assets/imported/textures is modified; 2D card art keeps its lossless settings.
Native source images are never resized or re-encoded by this tool.
"""
from pathlib import Path
import argparse
import json
import re


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--allow-partial', action='store_true', help='Configure descriptors already written by an interrupted first import')
    parser.add_argument('--invalidate-cache', action='store_true', help='Remove generated lossless outputs so a headless rescan rebuilds them as GPU textures')
    args = parser.parse_args()
    folder = args.project.resolve() / 'assets' / 'imported' / 'textures'
    changed = 0
    invalidated = 0
    images = [path for path in sorted(folder.iterdir()) if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'}]
    settings = {
        'compress/mode': '2',
        'compress/high_quality': 'false',
        'mipmaps/generate': 'true',
        'detect_3d/compress_to': '0',
        'process/size_limit': '0',
    }
    missing = [str(path) for path in images if not path.with_name(path.name + '.import').is_file()]
    if missing and not args.allow_partial:
        raise SystemExit(f'Import project first; {len(missing)} texture import files are absent')
    for image in images:
        metadata = image.with_name(image.name + '.import')
        if not metadata.is_file():
            continue
        original = metadata.read_text(encoding='utf-8')
        contents = original
        for key, value in settings.items():
            pattern = '^' + re.escape(key) + r'=.*$'
            if re.search(pattern, contents, flags=re.MULTILINE):
                contents = re.sub(pattern, key + '=' + value, contents, flags=re.MULTILINE)
            else:
                contents = contents.replace('[params]\n', '[params]\n' + key + '=' + value + '\n', 1)
        if contents != original:
            metadata.write_text(contents, encoding='utf-8')
            changed += 1
        if args.invalidate_cache and '"vram_texture": false' in contents:
            for resource_path in re.findall(r'"(res://\.godot/imported/[^"\n]+\.ctex)"', contents):
                output = (args.project.resolve() / resource_path.removeprefix('res://')).resolve()
                cache = (args.project.resolve() / '.godot' / 'imported').resolve()
                if not output.is_relative_to(cache):
                    raise ValueError('Generated texture path escaped the import cache')
                if output.is_file():
                    output.unlink()
                    invalidated += 1
                checksum = output.with_suffix('.md5')
                if checksum.is_file():
                    checksum.unlink()
    print(json.dumps({'creature_textures': len(images), 'changed_import_settings': changed, 'missing_descriptors': len(missing), 'invalidated_lossless_cache_files': invalidated}))


if __name__ == '__main__':
    main()
