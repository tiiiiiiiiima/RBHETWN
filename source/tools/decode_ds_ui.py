#!/usr/bin/env python3
"""Decode the raw LZ10 NCG/NCL/NSC/NCE resources in this user's DS dump.

Only graphics and manifests are emitted; neither the ROM nor executables are
copied into the Godot project. NCE frame geometry is retained, but runtime
affine/rotation/scale descriptors are recorded rather than approximated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw

SIZES = (
    ((8, 8), (16, 16), (32, 32), (64, 64)),
    ((16, 8), (32, 8), (32, 16), (64, 32)),
    ((8, 16), (8, 32), (16, 32), (32, 64)),
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def lz10(data: bytes) -> bytes:
    if len(data) < 4 or data[0] != 0x10:
        raise ValueError("Not an LZ10 resource")
    size = int.from_bytes(data[1:4], "little")
    if not 0 < size <= 32 * 1024 * 1024:
        raise ValueError("Invalid decompressed size")
    out = bytearray()
    cursor = 4
    while len(out) < size:
        if cursor >= len(data):
            raise ValueError("Truncated LZ10 flag")
        flag = data[cursor]
        cursor += 1
        for bit in range(7, -1, -1):
            if len(out) == size:
                break
            if flag & (1 << bit):
                if cursor + 2 > len(data):
                    raise ValueError("Truncated LZ10 backreference")
                value = int.from_bytes(data[cursor:cursor + 2], "big")
                cursor += 2
                length, distance = (value >> 12) + 3, (value & 4095) + 1
                if distance > len(out) or len(out) + length > size:
                    raise ValueError("Out-of-bounds LZ10 backreference")
                for _ in range(length):
                    out.append(out[-distance])
            else:
                if cursor >= len(data):
                    raise ValueError("Truncated LZ10 literal")
                out.append(data[cursor])
                cursor += 1
    return bytes(out)


def palette(data: bytes) -> list[tuple[int, int, int, int]]:
    if len(data) % 2:
        raise ValueError("Odd BGR555 palette size")
    result = []
    for (value,) in struct.iter_unpack("<H", data):
        # DS RGB555: low 5 bits are red, next green, then blue.
        result.append(tuple(((value >> shift) & 31) * 255 // 31
                            for shift in (0, 5, 10)) + (255,))
    return result


def tile_pixels(data: bytes, offset: int, bpp: int) -> list[int]:
    length = 32 if bpp == 4 else 64
    if offset < 0 or offset + length > len(data):
        raise ValueError("Tile pointer outside graphics")
    raw = data[offset:offset + length]
    if bpp == 8:
        return list(raw)
    return [n for value in raw for n in (value & 15, value >> 4)]


def tiled_image(data: bytes, offset: int, width: int, height: int,
                bpp: int, colors: list, bank: int = 0) -> Image.Image:
    image = Image.new("RGBA", (width, height))
    pixels = image.load()
    tile_size = 32 if bpp == 4 else 64
    for ty in range(height // 8):
        for tx in range(width // 8):
            values = tile_pixels(data, offset + (ty * (width // 8) + tx) * tile_size, bpp)
            for py in range(8):
                for px in range(8):
                    index = values[py * 8 + px]
                    color_index = index + (bank * 16 if bpp == 4 else 0)
                    if index and color_index >= len(colors):
                        raise ValueError("Color pointer outside palette")
                    pixels[tx * 8 + px, ty * 8 + py] = colors[color_index] if index else (0, 0, 0, 0)
    return image


def source_info(raw_root: Path, paths: list[Path]) -> list[dict]:
    return [{"path": str(p.relative_to(raw_root)), "bytes": p.stat().st_size,
             "sha256": sha(p.read_bytes()), "decompressed_sha256": sha(lz10(p.read_bytes()))}
            for p in paths]


def render_background(raw_root: Path, screen: Path) -> tuple[Image.Image, dict]:
    base = screen.name.removesuffix("_nsc.bin")
    graphic = screen.with_name(base + "_ncg.bin")
    colors_file = screen.with_name(base + "_ncl.bin")
    if not graphic.exists():
        # Direction/variant suffixes share their graphic and palette base.
        pieces = base.split("_")
        while len(pieces) > 1 and not graphic.exists():
            pieces.pop()
            graphic = screen.with_name("_".join(pieces) + "_ncg.bin")
            colors_file = screen.with_name("_".join(pieces) + "_ncl.bin")
    if not graphic.exists() or not colors_file.exists():
        raise ValueError("No exact/shared background NCG and NCL pair")
    graphics, color_data, map_data = (lz10(p.read_bytes()) for p in (graphic, colors_file, screen))
    if len(map_data) not in (1536, 2048):
        raise ValueError(f"Unsupported map size {len(map_data)}")
    entries = [v[0] for v in struct.iter_unpack("<H", map_data)]
    # All supported backgrounds use 256-color tiles: checked against graphics
    # length and every map entry, rather than inferred only from filename.
    max_tile = max(v & 1023 for v in entries)
    if len(graphics) % 64 or (max_tile + 1) * 64 > len(graphics) or len(color_data) != 512:
        raise ValueError("Background is not a bounded 8bpp/256-color tilemap")
    colors = palette(color_data)
    image = Image.new("RGBA", (256, 192))
    for i, entry in enumerate(entries[:32 * 24]):
        tile = tiled_image(graphics, (entry & 1023) * 64, 8, 8, 8, colors)
        if entry & 1024:
            tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if entry & 2048:
            tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        image.alpha_composite(tile, ((i % 32) * 8, (i // 32) * 8))
    return image, {"sources": source_info(raw_root, [graphic, colors_file, screen]),
                   "format": "LZ10/raw 8bpp tiled NCG + RGB555 NCL + 16-bit NSC",
                   "tilemap_size": [256, len(entries) // 32 * 8], "screen_size": [256, 192],
                   "transparent_index": 0}


def render_sprite(raw_root: Path, cell_file: Path,
                  palette_override: bytes | None = None) -> tuple[list[Image.Image], dict]:
    base = cell_file.name.removesuffix("_nce.bin")
    graphic = cell_file.with_name(base + ".nce_ncg1D.bin")
    colors_file = cell_file.with_name(base + "_ncl.bin")
    data = lz10(cell_file.read_bytes())
    graphics = lz10(graphic.read_bytes())
    colors = palette(palette_override if palette_override is not None else lz10(colors_file.read_bytes()))
    if len(data) < 16:
        raise ValueError("Truncated NCE header")
    _, sequence_count, sequence_offset, frame_offset, cell_offset = struct.unpack_from("<HHIII", data)
    if not 16 <= cell_offset <= frame_offset <= sequence_offset <= len(data):
        raise ValueError("Invalid NCE section ordering")
    if (frame_offset - cell_offset) % 12 or (sequence_offset - frame_offset) % 28:
        raise ValueError("Invalid NCE record alignment")
    cells = [struct.unpack_from("<HHHhhH", data, p)
             for p in range(cell_offset, frame_offset, 12)]
    frames = []
    descriptors = []
    # This ROM has both OBJ1D32 and OBJ1D128 sets (not consistently named).
    # Find the largest hardware boundary that keeps EVERY declared cell in
    # this graphics buffer. Reject resources when no valid boundary exists.
    boundaries = []
    for candidate in (32, 64, 128, 256):
        ends = []
        for attr0, attr1, attr2, _, _, _ in cells:
            shape, size = attr0 >> 14, attr1 >> 14
            if shape == 3:
                raise ValueError("Unsupported prohibited OAM shape")
            w, h = SIZES[shape][size]
            ends.append((attr2 & 1023) * candidate + w * h // (1 if attr0 & 8192 else 2))
        if max(ends, default=0) <= len(graphics):
            boundaries.append(candidate)
    if not boundaries:
        raise ValueError("No bounded OBJ1D tile-number boundary")
    boundary = 32 if "_32k" in base else max(boundaries)
    for index, p in enumerate(range(frame_offset, sequence_offset, 28)):
        first, count, duration = struct.unpack_from("<IHH", data, p)
        if first + count > len(cells):
            raise ValueError("Frame cell references outside NCE table")
        parts = []
        for attr0, attr1, attr2, x, y, flags in cells[first:first + count]:
            shape, size = attr0 >> 14, attr1 >> 14
            if shape == 3:
                raise ValueError("Unsupported prohibited OAM shape")
            width, height = SIZES[shape][size]
            bpp = 8 if attr0 & 8192 else 4
            bank = attr2 >> 12
            part = tiled_image(graphics, (attr2 & 1023) * boundary, width, height, bpp, colors, bank)
            affine = bool(attr0 & 256)
            if not affine and attr1 & 4096:
                part = part.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if not affine and attr1 & 8192:
                part = part.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            parts.append((x, y, part))
        if not parts:
            bounds = [0, 0, 1, 1]
        else:
            bounds = [min(x for x, _, _ in parts), min(y for _, y, _ in parts),
                      max(x + im.width for x, _, im in parts), max(y + im.height for _, y, im in parts)]
        width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        if width > 1024 or height > 1024:
            raise ValueError("NCE frame exceeds safe bounds")
        image = Image.new("RGBA", (width, height))
        # DS gives earlier OAM records priority over later ones.
        for x, y, part in reversed(parts):
            image.alpha_composite(part, (x - bounds[0], y - bounds[1]))
        frames.append(image)
        descriptors.append({"index": index, "cell_first": first, "cell_count": count,
                            "duration_ds_frames": duration, "origin": bounds[:2],
                            "size": [width, height], "descriptor_hex": data[p:p + 28].hex(),
                            "contains_affine_cells": any(bool(c[0] & 256)
                                                        for c in cells[first:first + count])})
    return frames, {"sources": source_info(raw_root, [graphic, colors_file, cell_file]),
                    "format": "LZ10/raw 4/8bpp OBJ1D NCG + RGB555 NCL + custom NCE",
                    "tile_number_boundary_bytes": boundary, "sequence_count": sequence_count,
                    "frame_descriptors": descriptors, "transparent_index": 0,
                    "limits": "Cell imagery/positions/flips decoded; runtime affine transforms and sequence playback are not reproduced."}


def save_atlas(images: list[Image.Image], target: Path, info: dict) -> None:
    width = max(im.width for im in images)
    height = max(im.height for im in images)
    columns = min(len(images), 8, max(1, 2048 // width))
    atlas = Image.new("RGBA", (columns * width, math.ceil(len(images) / columns) * height))
    for i, im in enumerate(images):
        x, y = i % columns * width, i // columns * height
        atlas.alpha_composite(im, (x, y))
        info["frame_descriptors"][i]["atlas_rect"] = [x, y, im.width, im.height]
    atlas.save(target)
    info["atlas_size"] = list(atlas.size)
    info["atlas_sha256"] = sha(target.read_bytes())


def selected_resources(root: Path):
    for directory in ("Game/Confrontation", "Game/Battle"):
        yield from sorted((root / directory / "Bg").glob("*_nsc.bin"))
        for p in sorted((root / directory / "Obj").glob("*_nce.bin")):
            if p.name.startswith(("select_", "retry_", "battle_shoot_b_ball_", "cutin_p")):
                continue
            yield p
    for base in ("union_b_obj_gp", "union_b_obj_number", "union_b_obj_cockpit"):
        p = root / "Game/2d/union_b" / (base + "_nce.bin")
        if p.exists():
            yield p
    # Native large card images, creature portraits and trainer icons. Small
    # duplicates and localized copies are deliberately excluded.
    for directory in ("Game/Card/Graphic/Large", "Game/Card/Graphic",
                      "Game/Bakugan/card", "Game/Character/Icon"):
        yield from sorted((root / directory).glob("*_nce.bin"))


RUNTIME_FRAMES = {
    "battle": ("Game_Battle_Obj_cutin_battle_nce", 2, "BATTLE!"),
    "stand": ("Game_Battle_Obj_cutin_stand_nce", 2, "STAND!"),
    "win": ("Game_Battle_Obj_cutin_win_nce", 2, "Victory!"),
    "lose": ("Game_Battle_Obj_cutin_lose_nce", 2, "You lost."),
    "game_start": ("Game_Battle_Obj_cutin_game_start_nce", 2, "GAME START"),
    "gate_won": ("Game_Battle_Obj_cutin_gate_card_get_nce", 2, "GATECARD WON!"),
    "critical_ko": ("Game_Battle_Obj_cutin_critical_ko_nce", 2, "Critical K.O.!"),
    "double_stand": ("Game_Battle_Obj_cutin_doublestand_nce", 2, "DOUBLE STAND"),
    "no_good": ("Game_Battle_Obj_cutin_no_count_nce", 2, "NO GOOD"),
    "ability": ("Game_Battle_Obj_battle_b_obj_ability_nce", 0, "Use an Ability card!"),
    "turn": ("Game_Battle_Obj_battle_b_obj_turn_nce", 0, "TURN"),
    "status": ("Game_Battle_Obj_battle_b_obj_state_nce", 0, "Blue hand phase icon; filename state"),
    "g_fill_player": ("Game_Confrontation_Obj_vs_b_obj_01_nce", 2, "Cyan horizontal comparison fill"),
    "g_fill_enemy": ("Game_Confrontation_Obj_vs_b_obj_01_nce", 0, "Red horizontal comparison fill"),
    "perfect": ("Game_Confrontation_Obj_vs_cutin_perfect_nce", 2, "Perfect!"),
    "vs_icon": ("Game_Confrontation_Obj_vs_b_obj_ability_nce", 2, "Silver VS emblem"),
    "card_back": ("Game_Card_Graphic_Large_card_l_000_nce", 0, "Native card back: Bakugan logo and orange burst"),
}

# Matched from the decoded creature portraits, then cross-checked against the
# actual English MES names. These are NOT compact MES indices inferred from
# numeric model IDs. Preyas/Angelo/Diablo identities were additionally checked
# against converted original model renders, correcting the initial portrait-
# only identification of 008 as base Preyas.
PORTRAIT_MATCHES = {
    "dragonoid": (0, 0), "delta_dragonoid": (1, 1),
    "tigrerra": (4, 2), "blade_tigrerra": (5, 3), "preyas": (6, 4),
    "preyas_ii_angelo": (7, 41), "preyas_ii_diablo": (8, 42),
    "gorem": (9, 7), "hammer_gorem": (10, 8), "skyress": (11, 9),
    "storm_skyress": (12, 10), "hydranoid": (13, 11), "dual_hydranoid": (14, 12),
    "reaper": (25, 13), "cycloid": (26, 14), "sirenoid": (27, 15),
    "fourtress": (28, 16), "tentaclear": (29, 17), "harpus": (30, 18),
    "juggernoid": (39, 19), "robotallion": (40, 20), "saurus": (41, 21),
    "serpenoid": (42, 22), "falconeer": (43, 23), "stinglash": (44, 24),
    "griffon": (45, 25), "laserman": (46, 26), "centipoid": (47, 27),
    "fear_ripper": (48, 28), "siege": (49, 29), "terrorclaw": (50, 30),
    "gargonoid": (52, 31), "manion": (56, 32), "ravenoid": (58, 33),
    "warius": (60, 34), "monarus": (61, 35), "leonidas": (62, 36),
    "omega_leonidas": (63, 37), "vladitor": (64, 38), "battle_ax_vladitor": (65, 39),
}

GATE_MATCHES = {
    "gate_dragonoid": (101, 1, "Dragonoid"),
    "gate_leonidas": (136, 36, "Leonidas"),
    "gate_griffon": (125, 25, "Griffon"),
    "gate_aquos_vortex": (217, 56, "Aquos Vortex"),
    "gate_the_cliffs": (220, 59, "The Cliffs"),
}


def export_native_names(manifest: dict, output: Path, raw_root: Path) -> None:
    from decode_ds_messages import decode_message_tables
    tables = decode_message_tables(raw_root)
    message_path = output.parent / "messages.json"
    message_path.write_text(json.dumps({"schema": 1, "tables": tables,
                                       "limits": "Glyphs decoded; control codes and game effect logic are not executed."},
                                      ensure_ascii=False, indent=2) + "\n")
    manifest["native_messages"] = {"path": "res://assets/ds/messages.json",
                                   "sha256": sha(message_path.read_bytes()),
                                   "tables": [{"source_path": t["source_path"],
                                               "source_sha256": t["source_sha256"],
                                               "record_count": len(t["records"])} for t in tables.values()]}
    by_id = {a["id"]: a for a in manifest["assets"]}
    name_records = tables["mes_BakuganName.mes"]["records"]
    manifest["native_portraits"] = {}
    attributes = ("Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus")
    for species, (ds_id, name_index) in PORTRAIT_MATCHES.items():
        asset = by_id.get(f"Game_Bakugan_card_bakugan_l_{ds_id:03}_nce")
        if not asset:
            continue
        descriptor = asset["frame_descriptors"][0]
        x, y, w, h = descriptor["atlas_rect"]
        atlas = Image.open(output / Path(asset["png"]).name)
        target = output / f"runtime_portrait_{species}.png"
        atlas.crop((x, y, x + w, y + h)).save(target)
        runtime = {"path": "res://assets/ds/ui/" + target.name, "frame": 0,
                   "source_asset": asset["id"], "meaning": name_records[name_index]["text"] + " source portrait",
                   "size": [w, h], "sha256": sha(target.read_bytes()),
                   "identity_basis": "Decoded portrait visual match, cross-checked against English MES name; runtime ID linkage not disassembled."}
        manifest["runtime"]["portrait_" + species] = runtime
        native = {"ds_resource_id": ds_id, "species_key": species,
                  "source_name": name_records[name_index]["text"], "name_message_index": name_index,
                  "name_source": "font/mes_BakuganName.mes", "source_asset": asset["id"],
                  "identity_basis": runtime["identity_basis"], "default_path": runtime["path"],
                  "attribute_palette_variants": {},
                  "palette_note": "First six 256-color banks: red/blue/brown/white/purple/green order is confirmed visually on Robotallion; named partners may have identical artwork in every bank."}
        cell_file = raw_root / asset["source_path"]
        color_file = cell_file.with_name(cell_file.name.removesuffix("_nce.bin") + "_ncl.bin")
        color_data = lz10(color_file.read_bytes())
        for bank, attribute in enumerate(attributes):
            if len(color_data) < (bank + 1) * 512:
                break
            # Extended trailing palettes are not attributed or copied. Only
            # the six ordinary source attribute banks are used here.
            images, _ = render_sprite(raw_root, cell_file, color_data[bank * 512:(bank + 1) * 512])
            variant = output / f"portrait_{species}_{attribute.lower()}.png"
            images[0].save(variant)
            native["attribute_palette_variants"][attribute] = {
                "path": "res://assets/ds/ui/" + variant.name, "palette_bank": bank,
                "palette_byte_offset": bank * 512, "size": list(images[0].size),
                "sha256": sha(variant.read_bytes()),
            }
        manifest["native_portraits"][species] = native
    manifest["unresolved_portrait_identities"] = {}
    manifest["portrait_identity_corrections"] = {
        "preyas_group": {
            "basis": "Converted source model visual review cross-checked against original portraits and MES names.",
            "006": "Base Preyas, MES name index 4.",
            "007": "Preyas II Angelo, explicit MES name index 41 (generic index 5).",
            "008": "Preyas II Diablo, explicit MES name index 42 (generic index 6).",
            "corrected_initial_assignment": "Initial portrait-only 008 to base Preyas was incorrect.",
        }
    }
    card_names = tables["mes_CardName.mes"]["records"]
    card_texts = tables["mes_CardText.mes"]["records"]
    numeric_cards = sorted((a for a in manifest["assets"]
                            if a["source_path"].startswith("Game/Card/Graphic/Large/card_l_")
                            and Path(a["source_path"]).name.removesuffix("_nce.bin").split("_")[-1].isdigit()),
                           key=lambda a: int(Path(a["source_path"]).name.removesuffix("_nce.bin").split("_")[-1]))
    if len(numeric_cards) == len(card_names) == len(card_texts):
        for index, asset in enumerate(numeric_cards):
            asset["name_record"] = {"name": card_names[index]["text"], "message_index": index,
                                    "name_source": "font/mes_CardName.mes", "effect_source": "font/mes_CardText.mes",
                                    "effect_text": card_texts[index]["text"],
                                    "binding_status": "Mechanical ascending numeric resource order aligned with equal MES count; runtime card parameter linkage not disassembled."}
    manifest["gate_art_matches"] = {}
    for key, (card_id, index, expected_name) in GATE_MATCHES.items():
        asset = by_id.get(f"Game_Card_Graphic_Large_card_l_{card_id:03}_nce")
        if not asset or card_names[index]["text"] != expected_name:
            continue
        descriptor = asset["frame_descriptors"][0]
        x, y, w, h = descriptor["atlas_rect"]
        atlas = Image.open(output / Path(asset["png"]).name)
        target = output / ("runtime_" + key + ".png")
        atlas.crop((x, y, x + w, y + h)).save(target)
        match = {"path": "res://assets/ds/ui/" + target.name, "frame": 0,
                 "source_asset": asset["id"], "source_card_id": card_id, "source_name": expected_name,
                 "name_message_index": index, "source_effect_text": card_texts[index]["text"],
                 "meaning": expected_name + " DS card art", "size": [w, h], "sha256": sha(target.read_bytes()),
                 "binding_status": "Exact source name matches existing GateCatalog title; numeric order/artwork cross-check. DS gameplay parameter linkage not disassembled."}
        manifest["runtime"][key] = match
        manifest["gate_art_matches"][key] = match


def export_runtime(manifest: dict, output: Path) -> None:
    manifest["runtime"] = {}
    by_id = {a["id"]: a for a in manifest["assets"]}
    for symbol, (asset_id, index, meaning) in RUNTIME_FRAMES.items():
        asset = by_id.get(asset_id)
        if not asset or index >= len(asset.get("frame_descriptors", [])):
            continue
        descriptor = asset["frame_descriptors"][index]
        x, y, w, h = descriptor["atlas_rect"]
        atlas = Image.open(output / Path(asset["png"]).name)
        frame = atlas.crop((x, y, x + w, y + h))
        box = frame.getbbox()
        if not box:
            continue
        frame = frame.crop(box)
        target = output / ("runtime_" + symbol + ".png")
        frame.save(target)
        manifest["runtime"][symbol] = {
            "path": "res://assets/ds/ui/" + target.name, "frame": index,
            "source_asset": asset_id, "meaning": meaning, "size": list(frame.size),
            "alpha_crop": list(box), "sha256": sha(target.read_bytes()),
        }
    for i, attribute in enumerate(("pyrus", "aquos", "subterra", "haos", "darkus", "ventus")):
        asset = by_id.get(f"Game_Confrontation_Obj_vs_emblem_{i:02}_32k_nce")
        if not asset:
            continue
        manifest["runtime"]["attribute_" + attribute] = {
            "path": asset["first_frame_png"], "frame": 0,
            "source_asset": asset["id"], "meaning": attribute + " attribute emblem", "size": [64, 64],
        }
    asset = by_id.get("Game_Battle_Obj_vs_u_obj_num_32k_nce")
    if asset:
        atlas = Image.open(output / Path(asset["png"]).name)
        for index, symbol in enumerate([str(n) for n in range(10)] + ["plus", "minus"]):
            x, y, w, h = asset["frame_descriptors"][index]["atlas_rect"]
            target = output / ("runtime_digit_" + symbol + ".png")
            atlas.crop((x, y, x + w, y + h)).save(target)
            manifest["runtime"]["digit_" + symbol] = {
                "path": "res://assets/ds/ui/" + target.name, "frame": index,
                "source_asset": asset["id"], "meaning": "Native DS white/cyan " + symbol + " numeral",
                "size": [w, h], "sha256": sha(target.read_bytes()),
            }
    asset = by_id.get("Game_Confrontation_Bg_vs_b_bg_02_nsc")
    if asset:
        source = Image.open(output / Path(asset["png"]).name)
        box = source.getbbox()
        target = output / "runtime_g_frame.png"
        source.crop(box).save(target)
        manifest["runtime"]["g_frame"] = {
            "path": "res://assets/ds/ui/" + target.name, "frame": 0,
            "source_asset": asset["id"], "meaning": "Metallic paired comparison bars; no numeric G text baked in",
            "size": list(source.crop(box).size), "alpha_crop": list(box), "sha256": sha(target.read_bytes()),
        }
    manifest["unresolved_runtime_symbols"] = {
        "gate_open": "No source label confidently identified. gate_won is GATECARD WON!, which is a different event.",
        "draw": "No source draw label identified. NO GOOD is not assigned as a draw label.",
        "ability_activate": "Decoded ability resource is the selection prompt, not an activation caption.",
        "g_letter": "Native comparison numerals identified; an isolated battle G glyph is not assigned.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--contact-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    args.contact_dir.mkdir(parents=True, exist_ok=True)
    manifest = {"schema": 1, "source_game": "Bakugan Battle Brawlers DS / supplied user archive",
                "decoder": "tools/decode_ds_ui.py", "assets": [], "skipped": [],
                "layout_status": "Source graphics decoded. Final screen layout requires emulator reference."}
    inventory_path = args.raw_root.parent / "inventory.json"
    if inventory_path.exists():
        inventory = json.loads(inventory_path.read_text())
        manifest["provenance"] = {
            "source_archive_name": Path(inventory["source"]["path"]).name,
            "source_archive_sha256": inventory["source"]["sha256"],
            "rom_sha256": inventory["rom"]["sha256"],
            "rom_game_code": inventory["rom"]["game_code"],
            "rom_in_project": False,
        }
    thumbnails = []
    for p in selected_resources(args.raw_root):
        key = "_".join(p.relative_to(args.raw_root).parts[:-1]) + "_" + p.name.removesuffix(".bin")
        target = args.output / (key + ".png")
        try:
            if p.name.endswith("_nsc.bin"):
                image, info = render_background(args.raw_root, p)
                image.save(target)
                info.update({"kind": "background", "size": list(image.size), "png_sha256": sha(target.read_bytes())})
                preview = image
            else:
                frames, info = render_sprite(args.raw_root, p)
                save_atlas(frames, target, info)
                info["kind"] = "sprite_atlas"
                # Contact sheets show several source frames, not just a tile dump.
                preview = Image.new("RGBA", (256, 192))
                for n, frame in enumerate(frames[:4]):
                    sample = frame.copy()
                    sample.thumbnail((124, 88), Image.Resampling.NEAREST)
                    preview.alpha_composite(sample, ((n % 2) * 128, (n // 2) * 96))
                # Small useful set of independently addressable first source frames.
                if p.name.startswith(("cutin_", "vs_emblem_")):
                    first_path = target.with_name(target.stem + "_first.png")
                    frames[0].save(first_path)
                    info["first_frame_png"] = "res://assets/ds/ui/" + first_path.name
            info.update({"id": key, "source_path": str(p.relative_to(args.raw_root)),
                         "png": "res://assets/ds/ui/" + target.name,
                         "meaning_status": "Source filename; visual interpretation must be checked in reference captures."})
            manifest["assets"].append(info)
            thumbnails.append((key, preview))
        except (ValueError, FileNotFoundError, IndexError, struct.error) as e:
            manifest["skipped"].append({"source_path": str(p.relative_to(args.raw_root)), "reason": str(e)})
    export_runtime(manifest, args.output)
    if (args.raw_root / "font/mes_BakuganName.mes").exists():
        export_native_names(manifest, args.output, args.raw_root)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    for page in range(math.ceil(len(thumbnails) / 24)):
        samples = thumbnails[page * 24:(page + 1) * 24]
        sheet = Image.new("RGB", (4 * 288, 6 * 224), (24, 25, 31))
        draw = ImageDraw.Draw(sheet)
        for i, (name, image) in enumerate(samples):
            x, y = i % 4 * 288, i // 4 * 224
            sample = image.copy()
            sample.thumbnail((256, 192), Image.Resampling.NEAREST)
            sheet.paste(sample, (x, y), sample)
            draw.text((x + 2, y + 192), name.replace("Game_", "")[:44], fill=(235, 235, 235))
        sheet.save(args.contact_dir / f"ds_ui_contact_{page:02}.png")
    print(json.dumps({"decoded_resources": len(manifest["assets"]), "skipped": manifest["skipped"],
                      "contact_pages": math.ceil(len(thumbnails) / 24)}, indent=2))


if __name__ == "__main__":
    main()
