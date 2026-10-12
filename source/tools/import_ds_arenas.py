#!/usr/bin/env python3
"""Convert selected, source-named Nintendo DS environments into embedded GLBs.

The user's ROM and uncompressed Nitro files stay outside the game project. This
script records the exact NitroFS paths and hashes; it does not redistribute a
ROM, execute its code, or infer gameplay collision from decorative geometry.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess


MAP = "Game/Battle/3d/Map"
GROUPS = {
    "pyrus_battle": ("battle", "Pyrus", ["Pyrus", "Pyrus_sky", "pyr_haichi0", "pyr_haichi1", "pyr_haichi2", "pyr_haichi3"], ["Pyrus"]),
    "aquos_battle": ("battle", "Aquos", ["aquos", "Aqu_bg1", "Aqu_bg2", "Aqu_bg3", "Aqu_bg4", "Aquos_sky"], ["aquos"]),
    "subterra_battle": ("battle", "Subterra", ["subterra", "Subterra_bg1", "Subterra_bg2", "Subterra_bg3", "Subterra_bg4", "Subterra_fl", "subterra_majin"], ["subterra"]),
    "haos_battle": ("battle", "Haos", ["Haos", "haos_bg1", "haos_bg2", "haos_bg3", "haos_bg4", "haos_cris", "haos_sky"], ["Haos"]),
    "darkus_battle": ("battle", "Darkus", ["Darkus", "Dark_bg1", "Dark_bg2", "Dark_bg3", "Dark_bg4", "Dark_uzu01", "Dark_uzu02"], ["Darkus"]),
    "ventus_battle": ("battle", "Ventus", ["ventus", "ventus_sky"], ["ventus"]),
    "toy_battle": ("battle", "Standard", ["00_Toy"], ["00_Toy"]),
    "anime_battle": ("battle", "Standard", ["anime"], ["anime"]),
    "pyrus_throw": ("throw", "Pyrus", ["Pyrusthrow_00"], ["Pyrusthrow_00"]),
    "aquos_throw": ("throw", "Aquos", ["aquosthrow_00", "aquosthrow_obj", "aqu_throwsky"], ["aquosthrow_00"]),
    "subterra_throw": ("throw", "Subterra", ["Subtethrow_00"], ["Subtethrow_00"]),
    "haos_throw": ("throw", "Haos", ["Haosthrow_00", "Haosthrow_tig"], ["Haosthrow_00"]),
    "darkus_throw": ("throw", "Darkus", ["Darkusthrow_00"], ["Darkusthrow_00"]),
    "ventus_throw": ("throw", "Ventus", ["ventusthrow_00", "ventus_skyth"], ["ventusthrow_00"]),
    "toy_throw": ("throw", "Standard", ["Toythrow_00"], ["Toythrow_00"]),
    "anime_throw": ("throw", "Standard", ["animethrow"], ["animethrow"]),
    "park_story": ("story", "Standard", ["story/map/cut_park"], ["story/map/cut_park"]),
    "standard_story": ("story", "Standard", ["story/map/cut_standard"], ["story/map/cut_standard"]),
}
MAGICS = {b"BMD0": "nsbmd", b"BTX0": "nsbtx", b"BCA0": "nsbca", b"BTA0": "nsbta", b"BTP0": "nsbtp", b"BVA0": "nsbva", b"BMA0": "nsbma"}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decompress_lz10(data: bytes) -> bytes:
    if not data or data[0] != 0x10:
        return data
    size = int.from_bytes(data[1:4], "little")
    if not 0 < size <= 16 * 1024 * 1024:
        raise ValueError("Invalid or excessive LZ10 expansion")
    out = bytearray()
    i = 4
    while len(out) < size:
        if i >= len(data):
            raise ValueError("Truncated LZ10 flags")
        flags = data[i]
        i += 1
        for bit in range(7, -1, -1):
            if len(out) == size:
                break
            if flags & (1 << bit):
                if i + 2 > len(data):
                    raise ValueError("Truncated LZ10 back-reference")
                first, second = data[i:i + 2]
                i += 2
                length = (first >> 4) + 3
                distance = ((first & 15) << 8 | second) + 1
                if distance > len(out) or len(out) + length > size:
                    raise ValueError("Invalid LZ10 back-reference")
                for _ in range(length):
                    out.append(out[-distance])
            else:
                if i >= len(data):
                    raise ValueError("Truncated LZ10 literal")
                out.append(data[i])
                i += 1
    return bytes(out)


def nitro_parts(data: bytes):
    for found in re.finditer(b"BMD0|BTX0|BCA0|BTA0|BTP0|BVA0|BMA0", data):
        start = found.start()
        if len(data) - start < 16:
            continue
        bom, version, size, header_size, sections = struct.unpack_from("<HHIHH", data, start + 4)
        if bom != 0xFEFF or not 1 <= sections <= 32 or header_size < 16 or size < 16 + 4 * sections or start + size > len(data):
            continue
        offsets = struct.unpack_from("<" + "I" * sections, data, start + 16)
        if any(off < header_size or off + 8 > size for off in offsets):
            continue
        yield found.group(), data[start:start + size], start


def source_path(stem: str, suffix: str) -> str:
    return f"{stem}{suffix}" if "/" in stem else f"{MAP}/{stem}{suffix}"


def embedded_glb(path: Path) -> bytes:
    """Retain source UV/materials while making converter output self-contained."""
    original = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", original)
    if magic != b"glTF" or version != 2 or length != len(original):
        raise ValueError(f"Invalid converted GLB: {path}")
    chunks = {}
    cursor = 12
    while cursor < length:
        size, kind = struct.unpack_from("<II", original, cursor)
        cursor += 8
        chunks[kind] = original[cursor:cursor + size]
        cursor += size
    doc = json.loads(chunks[0x4E4F534A])
    buffers = doc.get("buffers", [])
    if len(buffers) > 1 or any("uri" in buffer for buffer in buffers):
        raise ValueError("Converted GLB contains an external vertex buffer")
    binary = bytearray(chunks.get(0x004E4942, b""))
    changed = False
    for image in doc.get("images", []):
        if "uri" not in image:
            continue
        source = (path.parent / image["uri"]).resolve()
        if not source.is_relative_to(path.parent.resolve()) or not source.is_file():
            raise ValueError(f"Unsafe or missing converted texture: {image['uri']}")
        texture = source.read_bytes()
        if not texture.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("Expected a local PNG converted from DS texture data")
        binary.extend(b"\0" * (-len(binary) % 4))
        views = doc.setdefault("bufferViews", [])
        image["bufferView"] = len(views)
        image["mimeType"] = "image/png"
        del image["uri"]
        views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(texture)})
        binary.extend(texture)
        changed = True
    if not changed:
        return original
    doc["buffers"] = [{"byteLength": len(binary)}]
    serialized = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode()
    serialized += b" " * (-len(serialized) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    return struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(serialized) + 8 + len(binary)) + struct.pack("<II", len(serialized), 0x4E4F534A) + serialized + struct.pack("<II", len(binary), 0x004E4942) + binary


def remove_unmapped_animation_channels(data: bytes) -> tuple[bytes, int]:
    """Remove unexportable material targets instead of emitting invalid glTF."""
    json_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_size])
    removed = 0
    kept = []
    for animation in doc.get("animations", []):
        channels = animation.get("channels", [])
        valid = [channel for channel in channels if "node" in channel.get("target", {})]
        removed += len(channels) - len(valid)
        if valid:
            animation["channels"] = valid
            kept.append(animation)
    if not removed:
        return data, 0
    if kept:
        doc["animations"] = kept
    else:
        doc.pop("animations", None)
    serialized = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode()
    serialized += b" " * (-len(serialized) % 4)
    remaining = data[20 + json_size:]
    rebuilt = struct.pack("<4sII", b"glTF", 2, 20 + len(serialized) + len(remaining)) + struct.pack("<II", len(serialized), 0x4E4F534A) + serialized + remaining
    return rebuilt, removed


def prepare(raw_root: Path, staging: Path, relative: str) -> tuple[list[Path], dict]:
    src = raw_root / relative
    original = src.read_bytes()
    data = decompress_lz10(original)
    parts = list(nitro_parts(data))
    if not parts:
        raise ValueError(f"No Nitro resource in {relative}")
    output = []
    part_records = []
    prefix = relative.replace("/", "__").replace(".", "_")
    for number, (magic, part, offset) in enumerate(parts):
        destination = staging / f"{prefix}__{number}.{MAGICS[magic]}"
        destination.write_bytes(part)
        output.append(destination)
        part_records.append({"format": magic.decode(), "decoded_offset": offset, "size_bytes": len(part), "sha256": digest(part)})
    return output, {"path": relative, "size_bytes": len(original), "sha256": digest(original), "compression": "LZ10" if original[0] == 0x10 else "none", "nitro_parts": part_records}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_root", type=Path)
    parser.add_argument("--apicula", type=Path, required=True)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    args = parser.parse_args()
    args.staging.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    source_inventory = json.loads(args.inventory.read_text())
    converter_version = subprocess.check_output([str(args.apicula), "-V"], text=True).strip()
    manifest = {"schema_version": 1, "source": {"game_title": source_inventory["rom"]["title"], "game_code": source_inventory["rom"]["game_code"], "rom_sha256": source_inventory["rom"]["sha256"], "archive_sha256": source_inventory["source"]["sha256"]}, "conversion": {"tool": "apicula", "version": converter_version, "binary_sha256": digest(args.apicula.read_bytes()), "format": "glTF 2.0 embedded GLB", "coordinate_system": "source right-handed Y up, retained by converter", "material_animations": "NSBTA and NSBTP are inventoried but not exported by apicula; BMA0 and BVA0 are not supported by this converter", "collision": "Source geometry is visual. Existing analytic roll and card rules are not replaced by inferred DS collision."}, "groups": {}}
    prepared = {}

    def resource(relative):
        if relative not in prepared:
            prepared[relative] = prepare(args.raw_root, args.staging, relative)
        return prepared[relative]

    for group_id, (role, attribute, models, texture_stems) in GROUPS.items():
        destination = args.output / group_id
        destination.mkdir(exist_ok=True)
        texture_files = []
        texture_sources = []
        for stem in texture_stems:
            relative = source_path(stem, ".nsbtx")
            if (args.raw_root / relative).is_file():
                paths, record = resource(relative)
                texture_files.extend(paths)
                texture_sources.append(record)
        group = {"role": role, "attribute": attribute, "components": [], "texture_sources": texture_sources, "source_coordinates_preserved": True}
        for stem in models:
            relative = source_path(stem, ".nsbmd")
            model_files, model_record = resource(relative)
            companion_sources = []
            companions = []
            animation_relative = source_path(stem, "_data.bin")
            if (args.raw_root / animation_relative).is_file():
                paths, record = resource(animation_relative)
                companions.extend(path for path in paths if path.suffix in {".nsbca", ".nsbta", ".nsbtp"})
                companion_sources.append(record)
            component_id = stem.split("/")[-1]
            component_temp = args.staging / "converted" / group_id / component_id
            component_temp.mkdir(parents=True, exist_ok=True)
            command = [str(args.apicula), "convert", "-f=glb", "--overwrite", *map(str, model_files + texture_files + companions), "-o", str(component_temp)]
            converted = subprocess.run(command, capture_output=True, text=True)
            (component_temp / "conversion.log").write_text(converted.stdout + converted.stderr)
            if converted.returncode:
                raise RuntimeError(f"apicula failed for {relative}: {converted.stderr[-2000:]}")
            glbs = sorted(component_temp.glob("*.glb"))
            if not glbs:
                raise RuntimeError(f"No GLB converted for {relative}")
            for index, glb in enumerate(glbs):
                output_name = f"{component_id}{'__' + str(index) if len(glbs) > 1 else ''}.glb"
                output = destination / output_name
                glb_data, removed_channels = remove_unmapped_animation_channels(embedded_glb(glb))
                output.write_bytes(glb_data)
                group["components"].append({"id": component_id, "path": "res://assets/ds/arenas/" + group_id + "/" + output_name, "sha256": digest(output.read_bytes()), "size_bytes": output.stat().st_size, "source_model": model_record, "source_animations": companion_sources, "unmapped_material_animation_channels_removed": removed_channels})
        manifest["groups"][group_id] = group
    (args.output / "arena_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"groups": len(manifest["groups"]), "components": sum(len(g["components"]) for g in manifest["groups"].values()), "manifest": str(args.output / "arena_manifest.json")}))


if __name__ == "__main__":
    main()
