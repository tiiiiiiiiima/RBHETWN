#!/usr/bin/env bash
set -euo pipefail

# An installed Godot editor can run the packaged game with --main-pack; export
# templates and a network connection are not required for this portable build.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64}"
release_version="0.10"
package_name="Bakugan-$release_version-Linux"
build_dir="$project_dir/builds/$package_name"

if [[ ! -x "$godot_bin" ]]; then
    printf 'Godot executable not found: %s\nSet GODOT_BIN to Godot 4.6.3.\n' "$godot_bin" >&2
    exit 1
fi

# Fail before exporting the large native pack if release metadata is incomplete.
# JSON catalogs are explicitly included by export_presets.cfg.
for required in assets/imported/canonical_profiles.json assets/imported/trap_profiles.json assets/ds/ui_manifest.json assets/ds/models/model_manifest.json assets/ds/arenas/arena_manifest.json docs/RELEASE-0.10.md docs/CANONICAL-PROFILES-0.9.md docs/TRAPS-0.9.md docs/ANIME-DUEL-API-0.9.md; do
    if [[ ! -f "$project_dir/$required" ]]; then
        printf 'Required release file is missing: %s\n' "$required" >&2
        exit 1
    fi
done

mkdir -p "$build_dir" "$project_dir/builds/.xdg/data" "$project_dir/builds/.xdg/cache" "$project_dir/builds/.xdg/config"
export XDG_DATA_HOME="$project_dir/builds/.xdg/data"
export XDG_CACHE_HOME="$project_dir/builds/.xdg/cache"
export XDG_CONFIG_HOME="$project_dir/builds/.xdg/config"
export GODOT_SILENCE_ROOT_WARNING=1

"$godot_bin" --headless --path "$project_dir" --export-pack "Linux Portable" "$build_dir/arena.pck"
cp "$godot_bin" "$build_dir/BakuganPrototype-Linux.x86_64"
chmod 755 "$build_dir/BakuganPrototype-Linux.x86_64"
python3 - "$build_dir" <<'PYTHON'
import pathlib
import struct
import sys

build = pathlib.Path(sys.argv[1])
pack = (build / 'arena.pck').read_bytes()
with (build / 'BakuganPrototype-Linux.x86_64').open('ab') as executable:
    executable.write(pack)
    executable.write(struct.pack('<QI', len(pack), 0x43504447))
PYTHON

cat > "$build_dir/launch.sh" <<'LAUNCH'
#!/usr/bin/env sh
set -eu
game_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$game_dir/BakuganPrototype-Linux.x86_64" --main-pack "$game_dir/arena.pck" "$@"
LAUNCH
chmod 755 "$build_dir/launch.sh"

cat > "$build_dir/README-RU.txt" <<'README'
Bakugan Arena — прототип отдельной игры для ПК, версия 0.10

Linux x86_64. Распакуйте всю папку Bakugan-0.10-Linux.
Запустите BakuganPrototype-Linux.x86_64 двойным щелчком либо launch.sh.
Запуск из терминала:

    chmod +x launch.sh BakuganPrototype-Linux.x86_64
    ./launch.sh

Godot включён в сборку. Пакет игры встроен в исполняемый файл;
launch.sh использует отдельный arena.pck из той же папки.
Игра работает без сети. Требуется OpenGL 3.3 и видеодрайвер.

Обновление 0.10 добавляет исходные DS-боевые формы, арены и графику
интерфейса. Бой в обоих режимах показан в отдельной 3D-сцене;
правила, камера и физика остаются адаптацией ПК.
Полное описание режима игры, управления и сохраняемых данных:
README.md и RELEASE-0.10.md.

Исходные изображения и преобразованные модели входят в пакет;
игра не скачивает ресурсы во время запуска. Происхождение и авторы:
ASSET-SOURCES-0.7.md, ASSET-SOURCES-0.8.md, ASSET-SOURCES-0.10.md
и THIRD-PARTY-LICENSES.txt.
Изображения в коллекции карт не означают, что все их эффекты реализованы.
Исходные DS-ресурсы взяты из файла пользователя; ROM и BIOS не включены.
Отдельные боевые ресурсы Wii пока не получены.

Профиль прежних версий загружается автоматически из пользовательской
папки Godot «Bakugan — Arena Prototype». Распаковывайте обновление
целиком в новую папку. Версии используют прежнюю папку сохранений.
Выполненные проверки и их пределы: VALIDATION.md.
Лицензии движка и шрифта: GODOT-LICENSE.txt и FONT-LICENSE.txt.
README

cat > "$build_dir/GODOT-LICENSE.txt" <<'LICENSE'
Godot Engine is licensed under the MIT license.

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Third-party libraries used by this standard Godot build and their license
notices are listed in the bundled THIRD-PARTY-LICENSES.txt file.
LICENSE

cp "$project_dir/assets/FONT-LICENSE.txt" "$build_dir/FONT-LICENSE.txt"
for reference in RULES-COMPARISON.md WII-SOURCES.md TABLETOP-SOURCES.md FIDELITY.md VALIDATION.md DRAGONOID-REFERENCE.md CHANGELOG.md ASSET-SOURCES-0.7.md ASSET-SOURCES-0.8.md RELEASE-0.8.md RELEASE-0.9.md BLOXUGAN-COMPARISON-0.8.md ANIME-DUEL-API-0.8.md ANIME-DUEL-API-0.9.md CARD-LIBRARY-0.8.md CANONICAL-PROFILES-0.9.md TRAPS-0.9.md RELEASE-0.10.md ASSET-SOURCES-0.10.md DS-HUD-ASSETS.md DS-MODEL-CONVERSION.md DS-ARENAS.md DS-IMPORT-NOTES.md; do
    cp "$project_dir/docs/$reference" "$build_dir/$reference"
done

python3 - "$project_dir/README.md" "$build_dir/README.md" <<'PYTHON'
from pathlib import Path
import sys
import re
Path(sys.argv[2]).write_text(Path(sys.argv[1]).read_text(encoding='utf-8').replace('(docs/', '('), encoding='utf-8')
for document in Path(sys.argv[2]).parent.glob('*.md'):
    text = re.sub(r'\[([^\]]+)\]\(\.\./(assets/[^)]+)\)', lambda match: f'{match[1]} (`res://{match[2]}` внутри PCK)', document.read_text(encoding='utf-8'))
    document.write_text(text, encoding='utf-8')
PYTHON

# The Godot binary embeds its own full third-party license registry. Print
# it through the Engine singleton so the shipped runtime has matching notices.
license_script="$project_dir/builds/.print_licenses.gd"
cat > "$license_script" <<'GDSCRIPT'
extends SceneTree
func _initialize() -> void:
    print(Engine.get_license_text())
    for entry in Engine.get_copyright_info():
        print("\n", entry.get("name", ""))
        for part in entry.get("parts", []):
            for holder in part.get("copyright", []):
                print(holder)
            print("License: ", part.get("license", ""))
    for license_name in Engine.get_license_info():
        print("\n", license_name, "\n", Engine.get_license_info()[license_name])
    quit()
GDSCRIPT
"$build_dir/BakuganPrototype-Linux.x86_64" --headless --main-pack "$build_dir/arena.pck" --script "$license_script" > "$build_dir/THIRD-PARTY-LICENSES.txt"
cat "$project_dir/THIRD-PARTY-LICENSES.txt" >> "$build_dir/THIRD-PARTY-LICENSES.txt"
rm "$license_script"
chmod 644 "$build_dir"/*.txt "$build_dir"/*.md "$build_dir/arena.pck"

python3 - "$project_dir/builds" "$package_name" <<'PYTHON'
import pathlib
import sys
import zipfile

builds = pathlib.Path(sys.argv[1])
package_name = sys.argv[2]
with zipfile.ZipFile(builds / f'{package_name}.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    files = [
        'BakuganPrototype-Linux.x86_64', 'arena.pck', 'launch.sh',
        'README-RU.txt', 'GODOT-LICENSE.txt', 'THIRD-PARTY-LICENSES.txt',
        'FONT-LICENSE.txt', 'RULES-COMPARISON.md', 'WII-SOURCES.md',
        'TABLETOP-SOURCES.md', 'FIDELITY.md', 'VALIDATION.md',
        'DRAGONOID-REFERENCE.md', 'CHANGELOG.md', 'ASSET-SOURCES-0.7.md',
        'ASSET-SOURCES-0.8.md', 'RELEASE-0.8.md', 'RELEASE-0.9.md', 'README.md',
        'BLOXUGAN-COMPARISON-0.8.md',
        'ANIME-DUEL-API-0.8.md', 'ANIME-DUEL-API-0.9.md', 'CARD-LIBRARY-0.8.md',
        'CANONICAL-PROFILES-0.9.md', 'TRAPS-0.9.md',
        'RELEASE-0.10.md', 'ASSET-SOURCES-0.10.md', 'DS-HUD-ASSETS.md',
        'DS-MODEL-CONVERSION.md', 'DS-ARENAS.md', 'DS-IMPORT-NOTES.md',
    ]
    for name in files:
        entry = builds / package_name / name
        archive.write(entry, entry.relative_to(builds))
print('Created', builds / f'{package_name}.zip')
PYTHON
chmod 644 "$project_dir/builds/$package_name.zip"
