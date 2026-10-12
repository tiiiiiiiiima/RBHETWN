#!/usr/bin/env python3
"""Convert portrait-identified DS battle creatures with original joint motion.

Raw ROM/Nitro resources stay in staging outside the game project. Attribute
variants substitute supplied NTFP RGB555 palettes in the supplied NSBTX, then
use the same native texture decoder; no geometry or artwork is synthesized.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import struct
import subprocess

from import_ds_arenas import digest, decompress_lz10, prepare, embedded_glb

ATTRIBUTES = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
FIXED_ATTRIBUTES = {
    "dragonoid": "Pyrus", "delta_dragonoid": "Pyrus",
    "tigrerra": "Haos", "blade_tigrerra": "Haos", "preyas": "Aquos",
    "preyas_ii_angelo": "Haos", "preyas_ii_diablo": "Pyrus",
    "gorem": "Subterra", "hammer_gorem": "Subterra", "skyress": "Ventus",
    "storm_skyress": "Ventus", "hydranoid": "Darkus", "dual_hydranoid": "Darkus",
    "reaper": "Darkus", "cycloid": "Subterra", "sirenoid": "Aquos",
    "fourtress": "Pyrus", "tentaclear": "Haos", "harpus": "Ventus",
    "siege": "Pyrus", "vladitor": "Darkus", "battle_ax_vladitor": "Darkus",
}


def glb_doc(path: Path):
    data = path.read_bytes()
    chunks = {}
    position = 12
    while position < len(data):
        size, kind = struct.unpack_from("<II", data, position)
        position += 8
        chunks[kind] = data[position:position + size]
        position += size
    return json.loads(chunks[0x4E4F534A]), chunks.get(0x004E4942, b"")


def clean_animation_names(data: bytes) -> bytes:
    """Retain distinct source motions and collapse byte-identical bundle copies."""
    json_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_size])
    binary_start = 20 + json_size
    binary_size, binary_kind = struct.unpack_from("<II", data, binary_start)
    binary = data[binary_start + 8:binary_start + 8 + binary_size]
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

    def accessor_fingerprint(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        width = sizes[accessor["componentType"]] * widths[accessor["type"]]
        stride = view.get("byteStride", width)
        values = b"".join(binary[start + row * stride:start + row * stride + width] for row in range(accessor["count"]))
        return [accessor["componentType"], accessor["type"], accessor.get("normalized", False), digest(values)]

    retained = []
    counts = {}
    seen = {}
    duplicate_copies = []
    for animation in doc.get("animations", []):
        name = animation["name"]
        fingerprint = []
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            fingerprint.append([channel["target"], sampler.get("interpolation", "LINEAR"), accessor_fingerprint(sampler["input"]), accessor_fingerprint(sampler["output"])])
        signature = digest(json.dumps(fingerprint, sort_keys=True).encode())
        if signature in seen.get(name, []):
            duplicate_copies.append({"native_name": name, "curve_sha256": signature, "reason": "Identical native motion repeated by source bundle"})
            continue
        seen.setdefault(name, []).append(signature)
        counts[name] = counts.get(name, 0) + 1
        if counts[name] > 1:
            animation["name"] = name + f"__source{counts[name]}"
            animation.setdefault("extras", {})["native_animation_name"] = name
        retained.append(animation)
    doc["animations"] = retained
    if duplicate_copies:
        doc.setdefault("extras", {})["duplicate_native_animation_copies"] = duplicate_copies
    serialized = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode()
    serialized += b" " * (-len(serialized) % 4)
    return struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(serialized) + 8 + len(binary)) + struct.pack("<II", len(serialized), 0x4E4F534A) + serialized + struct.pack("<II", len(binary), binary_kind) + binary


def glb_summary(path: Path) -> dict:
    doc, binary = glb_doc(path)
    indices = {p["attributes"]["POSITION"] for mesh in doc.get("meshes", []) for p in mesh["primitives"]}
    minimum = [min(doc["accessors"][i]["min"][axis] for i in indices) for axis in range(3)]
    maximum = [max(doc["accessors"][i]["max"][axis] for i in indices) for axis in range(3)]
    animations = []
    for animation in doc.get("animations", []):
        duration = max(doc["accessors"][sampler["input"]].get("max", [0])[0] for sampler in animation["samplers"])
        animations.append({"name": animation["name"], "duration_seconds": duration, "channels": len(animation["channels"]), "role_status": "unverified native motion; numeric suffix retained"})
    height = maximum[1] - minimum[1]
    scale = 2.5 / height
    return {
        "mesh_count": len(doc.get("meshes", [])),
        "skin_count": len(doc.get("skins", [])),
        "joint_count": sum(len(skin["joints"]) for skin in doc.get("skins", [])),
        "material_count": len(doc.get("materials", [])),
        "embedded_texture_count": len(doc.get("images", [])),
        "source_bounds": {"minimum": minimum, "maximum": maximum},
        "transform": {"scale": scale, "position": [-(minimum[0] + maximum[0]) * scale / 2, -minimum[1] * scale, -(minimum[2] + maximum[2]) * scale / 2], "rotation_degrees": [0, 0, 0]},
        "normalization": {"target_height": 2.5, "floor_y": 0, "basis": "source bind geometry AABB", "facing": "source +Z, retained for game +Z"},
        "animations": animations,
        "animation_roles": {},
        "duplicate_native_animation_copies": doc.get("extras", {}).get("duplicate_native_animation_copies", []),
    }


def palette_metadata(info: str, texture: bytes):
    sections = struct.unpack_from("<H", texture, 14)[0]
    starts = struct.unpack_from("<" + "I" * sections, texture, 16)
    section = next(offset for offset in starts if texture[offset:offset + 4] == b"TEX0")
    palette_start = section + struct.unpack_from("<I", texture, section + 56)[0]
    return {
        name: palette_start + int(offset, 16)
        for name, offset in re.findall(r"Palette \d+:\n  Name: ([^\n]+)\n  Found In: [^\n]+\n  Offset: (0x[0-9a-fA-F]+)", info)
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_root", type=Path)
    parser.add_argument("--apicula", type=Path, required=True)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--ui-manifest", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, help="Existing canonical display names, keyed by species")
    parser.add_argument("--motion-evidence", type=Path, help="Visually reviewed native idle poses and bounds")
    parser.add_argument("--messages", type=Path, help="Decoded original English MES names")
    args = parser.parse_args()
    args.staging.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    inventory = json.loads(args.inventory.read_text())
    portraits = json.loads(args.ui_manifest.read_text())["native_portraits"]
    canonical_names = {}
    if args.catalog:
        canonical_names = {entry["key"]: entry["name"] for entry in json.loads(args.catalog.read_text())["species"]}
    motion_evidence = json.loads(args.motion_evidence.read_text()) if args.motion_evidence else {}
    source_names = {}
    if args.messages:
        source_names = {record["index"]: record["text"] for record in json.loads(args.messages.read_text())["tables"]["mes_BakuganName.mes"]["records"]}
    manifest = {
        "schema_version": 1,
        "source": {"game_title": inventory["rom"]["title"], "game_code": inventory["rom"]["game_code"], "rom_sha256": inventory["rom"]["sha256"], "archive_sha256": inventory["source"]["sha256"]},
        "conversion": {"tool": "apicula", "version": subprocess.check_output([str(args.apicula), "-V"], text=True).strip(), "binary_sha256": digest(args.apicula.read_bytes()), "format": "glTF 2.0 embedded GLB", "attribute_palettes": "Exact supplied RGB555 NTFP replaces named source NSBTX palette; original texture indices and materials are retained.", "palette_attribute_order": ATTRIBUTES, "palette_order_evidence": "Source palette colours checked visually against DS portraits: red/blue/brown/white/purple/green. Missing NTFP variants stay unavailable.", "unsupported_animation_types": "BMA0, BVA0, NSBTA and NSBTP retained in provenance only; apicula exports joint BCA0 motion.", "semantic_animation_roles": "Numeric clip suffixes are not semantic labels; roles require separate visual verification."},
        "species": {},
        "unmapped_source_models": [],
        "failures": [],
    }
    mapped_stems = set()
    for key, portrait in portraits.items():
        source_id = int(portrait["ds_resource_id"])
        stem = f"realb{source_id:02d}"
        mapped_stems.add(stem)
        staging = args.staging / key
        staging.mkdir(parents=True, exist_ok=True)
        try:
            model_files, model_record = prepare(args.raw_root, staging, f"Game/Realbaku/Mdl/{stem}.nsbmd")
            texture_files, texture_record = prepare(args.raw_root, staging, f"Game/Realbaku/Mdl/{stem}.nsbtx")
            companions = []
            animation_sources = []
            for source in sorted((args.raw_root / "Game/Realbaku/Mdl").glob(stem + "*_data.bin")):
                paths, record = prepare(args.raw_root, staging, str(source.relative_to(args.raw_root)))
                companions.extend(path for path in paths if path.suffix == ".nsbca")
                animation_sources.append(record)
            info = subprocess.check_output([str(args.apicula), "info", *map(str, model_files + texture_files + companions)], text=True)
            (staging / "native-info.txt").write_text(info)
            texture = texture_files[0].read_bytes()
            palettes = palette_metadata(info, texture)
            variants = {}

            def convert(identifier: str, tex_files: list[Path]):
                converted_dir = staging / "converted" / stem / identifier
                converted_dir.parent.mkdir(parents=True, exist_ok=True)
                command = [str(args.apicula), "convert", "-f=glb", "--overwrite", *map(str, model_files + tex_files + companions), "-o", str(converted_dir)]
                converted = subprocess.run(command, capture_output=True, text=True)
                converted_dir.mkdir(parents=True, exist_ok=True)
                (converted_dir / "conversion.log").write_text(converted.stdout + converted.stderr)
                if converted.returncode:
                    raise RuntimeError(converted.stderr[-2000:])
                if "couldn't be found" in converted.stdout + converted.stderr:
                    raise RuntimeError("Native material texture/palette did not resolve")
                glbs = list(converted_dir.glob("*.glb"))
                if len(glbs) != 1:
                    raise RuntimeError(f"Expected one battle mesh GLB, found {len(glbs)}")
                filename = key + ("_" + identifier if identifier != "native" else "") + ".glb"
                destination = args.output / filename
                destination.write_bytes(clean_animation_names(embedded_glb(glbs[0])))
                return {"path": "res://assets/ds/models/" + filename, "sha256": digest(destination.read_bytes()), "size_bytes": destination.stat().st_size}, glb_summary(destination)

            native, summary = convert("native", texture_files)
            native_matches = []
            for attribute_index, attribute in enumerate(ATTRIBUTES):
                updated = bytearray(texture)
                records = []
                equals_native = True
                for palette_name, offset in palettes.items():
                    palette_stem = palette_name.removesuffix("_pl")
                    relative = f"Game/Realbaku/Tex/{palette_stem}_{attribute_index:02d}.ntfp"
                    source = args.raw_root / relative
                    if not source.is_file():
                        continue
                    original = source.read_bytes()
                    replacement = decompress_lz10(original)
                    if len(replacement) not in {8, 16, 32, 64, 128, 256, 512} or offset + len(replacement) > len(updated):
                        raise RuntimeError("Invalid NTFP palette size/offset")
                    equals_native &= texture[offset:offset + len(replacement)] == replacement
                    updated[offset:offset + len(replacement)] = replacement
                    records.append({"path": relative, "size_bytes": len(original), "sha256": digest(original), "decoded_sha256": digest(replacement), "palette_name": palette_name, "nsbtx_offset": offset})
                if not records:
                    continue
                if equals_native:
                    native_matches.append(attribute)
                patched = staging / (attribute.lower() + ".nsbtx")
                patched.write_bytes(updated)
                variant, variant_summary = convert(attribute.lower(), [patched])
                if variant_summary["material_count"] != summary["material_count"]:
                    raise RuntimeError("Attribute variant changed native material topology")
                variant["source_palettes"] = records
                variant["modified_palette_count"] = len(records)
                variant["shared_native_palette_count"] = len(palettes) - len(records)
                variants[attribute] = variant
            native_attribute = native_matches[0] if len(native_matches) == 1 else FIXED_ATTRIBUTES.get(key, "")
            if not variants and native_attribute:
                variants[native_attribute] = native.copy()
            species = {
                "key": key, "name": canonical_names.get(key, portrait["source_name"]), "source_name": source_names.get(portrait.get("name_message_index"), portrait["source_name"]), "source_name_message_index": portrait.get("name_message_index"), "ds_resource_id": source_id,
                "actual_form": "battle", **native, **summary,
                "native_attribute": native_attribute,
                "native_attribute_basis": "NSBTX bytes equal supplied attribute NTFP" if len(native_matches) == 1 else "fixed partner appearance cross-checked with decoded source portrait" if native_attribute else "unverified; retained native source appearance",
                "variants": variants,
                "identity_basis": portrait["identity_basis"] + " Matching realb resource suffix; battle geometry checked separately.",
                "source": {"model": model_record, "textures": texture_record, "animations": animation_sources},
            }
            evidence = motion_evidence.get(key, {})
            if str(evidence.get("idle_status", "")).startswith("verified") and int(evidence.get("ds_resource_id", -1)) == source_id:
                species["transform"] = evidence["suggested_transform"]
                species["normalization"]["basis"] = "polygon-referenced source mesh vertices at verified native idle start/middle/end"
                species["normalization"]["source_pose_bounds"] = evidence["source_pose_bounds"]
                species["animation_roles"]["idle"] = evidence["native_clip"]
                species["animation_role_evidence"] = {"idle": evidence["idle_status"], "endpoint_vertex_rms_delta_per_height": evidence["endpoint_vertex_rms_delta_per_height"], "midpoint_vertex_max_delta_per_height": evidence["midpoint_vertex_max_delta_per_height"]}
            manifest["species"][key] = species
            print(json.dumps({"species": key, "clips": len(summary["animations"]), "variants": list(variants), "native_attribute": native_attribute}), flush=True)
        except Exception as error:
            manifest["failures"].append({"species": key, "source_model": stem, "error": str(error)})
            print(json.dumps({"species": key, "error": str(error)}), flush=True)
    for source in sorted((args.raw_root / "Game/Realbaku/Mdl").glob("*.nsbmd")):
        if "_" not in source.stem and source.stem not in mapped_stems:
            manifest["unmapped_source_models"].append({"path": str(source.relative_to(args.raw_root)), "sha256": digest(source.read_bytes()), "reason": "No portrait-verified species identity; not assigned to a different species."})
    manifest["coverage"] = {"battle_species": len(manifest["species"]), "attribute_variants": sum(len(value["variants"]) for value in manifest["species"].values()), "native_joint_clips": sum(len(value["animations"]) for value in manifest["species"].values()), "failed_species": len(manifest["failures"])}
    destination = args.output / "model_manifest.json"
    temporary = destination.with_suffix(".tmp")
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(destination)
    print(json.dumps({"manifest": str(destination), **manifest["coverage"]}))


if __name__ == "__main__":
    main()
