#!/usr/bin/env python3
"""Build a browsable catalog from the supplied DS card graphics and MES text.

This records the numeric artwork/message alignment already present in the UI
manifest. It does not reconstruct the ROM's card parameter table or effects.
All artwork remains the existing, unchanged decoded native PNG.
"""
import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

GROUPS = {
    1: ("gate", "gold", "Золотые карты ворот", 39),
    2: ("gate", "silver", "Серебряные карты ворот", 32),
    3: ("gate", "copper", "Медные карты ворот", 32),
    4: ("ability", "red", "Красные карты способностей", 32),
    5: ("ability", "green", "Зелёные карты способностей", 32),
    6: ("ability", "blue", "Синие карты способностей", 33),
    7: ("special", "special", "Специальные карты поля", 12),
}
ART_MATCHES = {
    "gate_dragonoid": (101, "Dragonoid", "Dragonoids get the Gate bonus twice!"),
    "gate_leonidas": (136, "Leonidas", "Leonidases get the Gate bonus twice!"),
    "gate_griffon": (125, "Griffon", "Griffons get the Gate bonus twice!"),
    "gate_aquos_vortex": (217, "Aquos Vortex", "<0xff85>"),
    "gate_the_cliffs": (220, "The Cliffs", "<0xff85>"),
    "gate_sunrise": (215, "Sunrise", "<0xff85>"),
    "gate_stand_your_ground": (306, "Stand Your Ground", "Both players regain all Ability Cards."),
    "ability_boosted_dragon": (511, "Boosted Dragon", "Dragonoid gets +200 G-Power."),
    "ability_mega_impact": (516, "Mega Impact", "Gorem gets +200 G-Power."),
    "ability_alpha_blaster": (527, "Alpha Blaster", "Leonidas gets +200 G-Power."),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def native_path(project: Path, resource: str) -> Path:
    if not resource.startswith("res://assets/ds/ui/"):
        raise ValueError("Native card image must remain under DS UI assets")
    path = project / resource.removeprefix("res://")
    if not path.resolve().is_relative_to((project / "assets/ds/ui").resolve()):
        raise ValueError("Native card image escapes DS UI assets")
    return path


def build_catalog(project: Path, raw_root: Path | None = None) -> dict:
    manifest_path = project / "assets/ds/ui_manifest.json"
    messages_path = project / "assets/ds/messages.json"
    ui = json.loads(manifest_path.read_text())
    messages = json.loads(messages_path.read_text())
    tables = messages["tables"]
    names = tables["mes_CardName.mes"]["records"]
    texts = tables["mes_CardText.mes"]["records"]
    if len(names) != 213 or len(texts) != 213:
        raise ValueError("Expected complete 213-entry DS card message tables")
    assets = {}
    for asset in ui["assets"]:
        match = re.fullmatch(r"Game_Card_Graphic_Large_card_l_(\d{3})_nce", asset["id"])
        if match:
            card_id = int(match[1])
            if card_id in assets:
                raise ValueError("Duplicate native card artwork identifier")
            assets[card_id] = asset
    expected_ids = [0] + [group * 100 + offset for group, data in GROUPS.items()
                          for offset in range(1, data[3] + 1)]
    if sorted(assets) != expected_ids:
        raise ValueError("Native card artwork is missing or numeric alignment changed")
    cards = []
    for message_index, card_id in enumerate(expected_ids):
        asset = assets[card_id]
        name, text = names[message_index], texts[message_index]
        binding = asset["name_record"]
        if name["index"] != message_index or text["index"] != message_index:
            raise ValueError("MES records have unexpected indices")
        if (binding["message_index"] != message_index or binding["name"] != name["text"]
                or binding["effect_text"] != text["text"]):
            raise ValueError("Existing UI card/message association does not agree")
        if name["unresolved_control_codes"]:
            raise ValueError("Card name contains unresolved glyphs")
        frames = asset["frame_descriptors"]
        if len(frames) != 1 or frames[0]["atlas_rect"] != [0, 0, 96, 128]:
            raise ValueError("Unexpected native card face extent")
        image_path = native_path(project, asset["png"])
        if sha(image_path.read_bytes()) != asset["atlas_sha256"]:
            raise ValueError("Native card pixels changed from decoded source")
        if raw_root is not None:
            for source in asset["sources"]:
                if sha((raw_root / source["path"]).read_bytes()) != source["sha256"]:
                    raise ValueError("Native source file hash mismatch")
        if card_id == 0:
            continue
        kind, color, category, _ = GROUPS[card_id // 100]
        marker_only = (text["text"] == "<0xff85>"
                       and [code for code in text["code_units"] if code != 0xFF80] == [0xFF85])
        cards.append({
            "key": f"ds_card_{card_id:03}", "source_card_id": card_id,
            "message_index": message_index, "name": name["text"],
            "kind": kind, "color_type": color, "category": category,
            "aliases": [f"DS {card_id:03}", color], "available": True,
            "path": asset["png"], "size": [96, 128],
            "source_description": "" if marker_only else text["text"],
            "source_effect_text": text["text"],
            "description_status": "control_marker_only" if marker_only else "decoded_native_text",
            "unresolved_control_codes": text["unresolved_control_codes"],
            "name_code_units": name["code_units"], "effect_code_units": text["code_units"],
            "source_asset": asset["id"], "image_sha256": asset["atlas_sha256"],
            "sources": asset["sources"],
            "name_source": tables["mes_CardName.mes"]["source_path"],
            "effect_source": tables["mes_CardText.mes"]["source_path"],
            "binding_status": binding["binding_status"],
            "classification_status": "Numeric resource groups with native color/title artwork cross-check",
            "playable": False, "gameplay_parameter_status": "Not decoded or executed",
        })
    matches = {}
    by_id = {card["source_card_id"]: card for card in cards}
    for existing_key, (card_id, expected_name, expected_text) in ART_MATCHES.items():
        entry = by_id[card_id]
        if entry["name"] != expected_name or entry["source_effect_text"] != expected_text:
            raise ValueError(f"Exact-name artwork match changed: {existing_key}")
        matches[existing_key] = {
            "key": entry["key"], "path": entry["path"], "source_card_id": card_id,
            "message_index": entry["message_index"], "source_name": expected_name,
            "source_effect_text": expected_text,
            "binding_status": "Exact native name/effect text association; art only, native numeric boost table unverified",
        }
    back_asset = assets[0]
    return {
        "schema": 1, "source_game": "Bakugan Battle Brawlers DS / user-supplied B6RE archive",
        "provenance": ui["provenance"],
        "input_hashes": {"ui_manifest.json": sha(manifest_path.read_bytes()),
                         "messages.json": sha(messages_path.read_bytes())},
        "message_sources": {key: {field: value for field, value in tables[key].items()
                                   if field != "records"}
                            for key in ("mes_CardName.mes", "mes_CardText.mes")},
        "counts": {"cards": len(cards), "by_kind": dict(Counter(c["kind"] for c in cards)),
                   "by_color": dict(Counter(c["color_type"] for c in cards)),
                   "descriptions": sum(bool(c["source_description"]) for c in cards),
                   "control_marker_only_descriptions": sum(c["description_status"] == "control_marker_only" for c in cards)},
        "cards": cards,
        "backs": [{"key": "ds_card_back", "path": back_asset["png"], "available": True,
                   "source_card_id": 0, "source_asset": back_asset["id"],
                   "image_sha256": back_asset["atlas_sha256"], "sources": back_asset["sources"]}],
        "existing_art_matches": matches,
        "limits": ["Names and artwork use ascending numeric resource order aligned to equal MES count; runtime ROM card parameter linkage is unverified.",
                   "Original English descriptions are preserved; control-marker-only descriptions remain empty with original code units recorded.",
                   "No numeric gate bonuses, ability parameter tables, or executable effects are inferred.",
                   "Collection entries do not add playable effects; original 96x128 DS faces are unchanged."],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--raw-root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = build_catalog(args.project, args.raw_root)
    target = args.output or args.project / "assets/ds/source_cards.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result["counts"]))


if __name__ == "__main__":
    main()
