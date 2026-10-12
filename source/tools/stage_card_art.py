#!/usr/bin/env python3
"""Extract selected TTS atlas cells without resizing or altering source pixels.

The downloaded source atlases stay in the research cache. Their SHA-256, URLs,
cell rectangles and decoded pixel hashes are retained in the shipped manifest.
Individual faces avoid loading a 262 MB atlas to display one card. This is asset
extraction, not a recreation of the printed art or a change to gameplay rules.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


GATE_KEYS = [
    "gate_leonidas", "gate_aquos_vortex", "gate_ability_block",
    "gate_dragonoid", "gate_the_cliffs", "gate_quick_strike",
    "gate_griffon", "gate_sunrise", "gate_stand_your_ground",
]
ABILITY_KEYS = [
    "ability_battle_gate", "ability_alpha_blaster", "ability_g_power_boost",
    "ability_quick_draw", "ability_boosted_dragon", "ability_g_power_bump",
    "ability_mega_impact",
]
MISMATCHES = {
    "gate_dragonoid": "TTS Subterra +110 / Darkus +110; console +80 / +100.",
    "gate_griffon": "TTS Aquos +100 / Haos +100; console +40 / +80.",
    "gate_quick_strike": "TTS bonuses and last-standing effect differ from the console card.",
    "ability_battle_gate": "TTS attribute/power-level bonus differs from the console different-attribute +100 G.",
}
MISSING = {
    "gate_ability_block": "No matching Ability Block face was found in the source save.",
    "ability_quick_draw": "No matching Quick Draw face was found in the source save.",
}


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def pixel_hash(image: Image.Image) -> str:
    return sha_bytes(image.convert("RGBA").tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path("/tmp/bakugan07-research"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    source_cards = json.loads((args.cache / "tts-game-card-map.json").read_text())
    download_records = json.loads((args.cache / "download-results.json").read_text())
    downloads = {record["key"]: record for record in download_records}
    destination = args.project / "assets/imported/cards"
    destination.mkdir(parents=True, exist_ok=True)
    back = downloads["card_back_3ad919bfabd98a3b"]
    assert back["ok"], "Source card back download failed"
    back_source = args.cache / "downloads" / f"{back['key']}.png"
    assert sha_file(back_source) == back["sha256"]
    back_output = destination / "back.png"
    shutil.copyfile(back_source, back_output)
    with Image.open(back_output) as image:
        back_info = {
            "path": "res://assets/imported/cards/back.png",
            "source_url": back["url"],
            "source_sha256": back["sha256"],
            "sha256": sha_file(back_output),
            "dimensions": list(image.size),
            "pixel_sha256": pixel_hash(image),
            "transformation": "original_png_byte_copy",
        }
    manifest = {
        "schema": 1,
        "source": {
            "workshop_id": "2480698294",
            "workshop_url": "https://steamcommunity.com/sharedfiles/filedetails/?id=2480698294",
            "creators": ["MrZangetsu", "Peridot", "Bakugan TTS Community"],
            "printed_illustration_credit": "@MrZangetsu",
        },
        "extraction": "Lossless rectangular pixel extraction from TTS card atlases; no resizing, recoloring, retouching or rules changes.",
        "back": back_info,
        "gates": [],
        "abilities": [],
    }
    # Only one large atlas is decoded at a time, keeping memory bounded.
    for index, source_card in enumerate(source_cards):
        kind = "gates" if index < len(GATE_KEYS) else "abilities"
        card_index = index if kind == "gates" else index - len(GATE_KEYS)
        key = (GATE_KEYS if kind == "gates" else ABILITY_KEYS)[card_index]
        matches = source_card["source_matches"]
        card = {
            "index": card_index,
            "key": key,
            "name": source_card["game_card_name"],
            "original_card_found": bool(matches),
            "full_face_matches_console_rules": bool(matches) and key not in MISMATCHES,
            "printed_face_visually_checked": bool(matches),
        }
        if not matches:
            card.update({
                "path": back_info["path"],
                "dimensions": back_info["dimensions"],
                "sha256": back_info["sha256"],
                "display_mode": "source_back_fallback",
                "fallback_reason": MISSING[key],
                "source_url": back_info["source_url"],
                "source_sha256": back_info["source_sha256"],
                "source_card_name": "",
            })
        else:
            match = matches[0]
            record = downloads[match["face"]]
            assert record["ok"], f"Source atlas download failed: {match['face']}"
            source_path = args.cache / "downloads" / f"{record['key']}.png"
            assert sha_file(source_path) == record["sha256"]
            with Image.open(source_path) as atlas:
                columns, rows = match["columns"], match["rows"]
                assert atlas.width % columns == 0 and atlas.height % rows == 0
                width, height = atlas.width // columns, atlas.height // rows
                cell = match["card_id"] % 100
                assert cell < columns * rows
                x, y = (cell % columns) * width, (cell // columns) * height
                image = atlas.crop((x, y, x + width, y + height))
                original_pixels = pixel_hash(image)
                output = destination / f"{key}.png"
                image.save(output)
                with Image.open(output) as result:
                    assert pixel_hash(result) == original_pixels, f"Pixels changed: {key}"
                # Rectangles exclude all source numbers and rules. Gate titles
                # run down the right margin; blue ability values run down left.
                if kind == "gates":
                    illustration = [184, 184, 497, 714]
                elif key in ("ability_g_power_boost", "ability_g_power_bump"):
                    illustration = [151, 211, 585, 576]
                else:
                    illustration = [45, 208, 691, 579]
                rx, ry, rw, rh = illustration
                assert 0 <= rx < rx + rw <= width and 0 <= ry < ry + rh <= height
                illustration_pixels = pixel_hash(image.crop((rx, ry, rx + rw, ry + rh)))
            card.update({
                "path": f"res://assets/imported/cards/{key}.png",
                "dimensions": [width, height],
                "sha256": sha_file(output),
                "pixel_sha256": original_pixels,
                "illustration_pixel_sha256": illustration_pixels,
                "illustration_rect": illustration,
                "display_mode": "source_illustration" if key in MISMATCHES else "source_face",
                "fallback_reason": MISMATCHES.get(key, ""),
                "source_card_name": match["name"],
                "source_description": match["description"],
                "source_save_path": match["source_path"],
                "source_url": record["url"],
                "source_sha256": record["sha256"],
                "source_card_id": match["card_id"],
                "source_atlas_dimensions": [columns * width, rows * height],
                "source_atlas_grid": [columns, rows],
                "source_cell_rect": [x, y, width, height],
                "transformation": "lossless_pixel_crop",
            })
        manifest[kind].append(card)
        print(f"{key}: {card['display_mode']}", flush=True)
    target = args.project / "assets/imported/cards.json"
    target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Staged {len(GATE_KEYS)} gates / {len(ABILITY_KEYS)} abilities; {sum(p.stat().st_size for p in destination.glob('*.png')):,} PNG bytes.")


if __name__ == "__main__":
    main()
