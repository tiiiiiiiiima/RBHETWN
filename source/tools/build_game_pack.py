#!/usr/bin/env python3
"""Export only the desktop game PCK and runtime notices, without a Linux ZIP.

Use its arena.pck with build_windows_package.py --pck. This does not download
engines or mutate a previous release's archives. Godot imports should finish
and release validation should pass before running this exporter.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


LICENSE_SCRIPT = """extends SceneTree
func _initialize() -> void:
    print(Engine.get_license_text())
    for entry in Engine.get_copyright_info():
        print("\\n", entry.get("name", ""))
        for part in entry.get("parts", []):
            for holder in part.get("copyright", []):
                print(holder)
            print("License: ", part.get("license", ""))
    for license_name in Engine.get_license_info():
        print("\\n", license_name, "\\n", Engine.get_license_info()[license_name])
    quit()
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"), help="Installed Godot 4.6.3 executable")
    parser.add_argument("--version", help="Must match project.godot, defaults to its release version")
    parser.add_argument("--output-root", type=Path, help="Pack root; defaults to project builds")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    match = re.search(r'^config/version="([0-9.]+)"$', (project / "project.godot").read_text(), re.M)
    if not match:
        raise SystemExit("Missing numeric project version")
    version = match.group(1).removesuffix(".0")
    if args.version and args.version != version:
        raise SystemExit("Requested release does not match project.godot")
    if not args.godot or not Path(args.godot).is_file():
        raise SystemExit("Godot executable missing; set --godot")
    destination = (args.output_root or project / "builds") / f"Bakugan-{version}-Pack"
    destination.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    for key, name in [("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")]:
        folder = project / "builds/.xdg-pack" / name
        folder.mkdir(parents=True, exist_ok=True)
        environment[key] = str(folder)
    environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
    engine_version = subprocess.run([args.godot, "--version"], check=True, capture_output=True, text=True, env=environment).stdout.strip()
    if not engine_version.startswith("4.6.3."):
        raise SystemExit("This package requires the pinned Godot 4.6.3 runtime")
    pack = destination / "arena.pck"
    subprocess.run([args.godot, "--headless", "--path", str(project), "--export-pack",
                    "Linux Portable", str(pack)], check=True, env=environment)
    with tempfile.TemporaryDirectory(prefix="bakugan-license-", dir="/tmp") as workdir:
        script = Path(workdir) / "licenses.gd"
        script.write_text(LICENSE_SCRIPT, encoding="utf-8")
        registry = subprocess.run([args.godot, "--headless", "--main-pack", str(pack),
                                   "--script", str(script)], check=True, capture_output=True, text=True, env=environment)
    engine_license = registry.stdout.split("\n", 2)[-1] if registry.stdout.startswith("Godot Engine") else registry.stdout
    # Engine.get_license_text is the engine MIT text; retain the full registry
    # separately, then append the project's asset provenance notices.
    marker = "SOFTWARE."
    if marker not in engine_license:
        raise SystemExit("Engine did not emit its license text")
    license_text = engine_license[:engine_license.index(marker) + len(marker)] + "\n"
    (destination / "GODOT-LICENSE.txt").write_text(license_text, encoding="utf-8")
    (destination / "THIRD-PARTY-LICENSES.txt").write_text(
        engine_license + "\n" + (project / "THIRD-PARTY-LICENSES.txt").read_text(encoding="utf-8"), encoding="utf-8")
    shutil.copy2(project / "assets/FONT-LICENSE.txt", destination / "FONT-LICENSE.txt")
    with pack.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    print(json.dumps({"version": version, "godot": engine_version, "pck": str(pack), "bytes": pack.stat().st_size,
                      "sha256": digest, "linux_package_built": False}, indent=2))


if __name__ == "__main__":
    main()
