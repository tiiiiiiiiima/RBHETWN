#!/usr/bin/env python3
"""Stage every referenced card face from Workshop 3412700725, losslessly.

This is an offline asset extraction step. The root downloader supplies the
source files declared in download-jobs.json. It copies standalone PNG faces
byte for byte and crops atlas cells at their native resolution without edits.
Neither the source wording nor the printed effects become gameplay rules.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image, UnidentifiedImageError


# Explicitly supplied TTS atlases can exceed Pillow's conservative 89 MP limit.
# Still reject unreasonable images rather than turning the protection off.
Image.MAX_IMAGE_PIXELS = 250_000_000


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pixel_hash(image: Image.Image) -> str:
    return sha_bytes(image.convert("RGBA").tobytes())


def card_key(record: dict) -> str:
    identity = "|".join(str(record[field]) for field in ("face_url", "columns", "rows", "cell"))
    return "source_card_" + sha_bytes(identity.encode("utf-8"))[:20]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path("/tmp/bakugan08-research"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--allow-missing", action="store_true", help="Retain unavailable entries with explicit missing metadata.")
    args = parser.parse_args()
    inventory = json.loads((args.cache / "all-source-cards.json").read_text())
    jobs = {job["key"]: job for job in json.loads((args.cache / "download-jobs.json").read_text())}
    records = inventory["cards"]
    assert not inventory.get("unresolved_cards"), "Unresolved card references require an explicit source audit."
    identities = [card_key(record) for record in records]
    assert len(set(identities)) == len(identities), "Duplicate face cells must be merged in the source inventory."
    destination = args.project / "assets/imported/source_cards"
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": 1,
        "source": {
            "workshop_id": "3412700725",
            "workshop_url": "https://steamcommunity.com/sharedfiles/filedetails/?id=3412700725",
            "title": "Bakugan Anime Style Format",
            "related_model_workshop_id": "2480698294",
            "creators": ["MrZangetsu", "Low Taper Fade Rat", "laval2400", "Maxh1gh", "rush808"],
            "template_credit": "BakuganNewGame",
            "model_credit": "MrZangetsu1997",
            "credits": "The workshop authors and credited card collaborators; individual source captions are retained.",
            "inventory_sha256": sha_file(args.cache / "all-source-cards.json"),
        },
        "extraction": "Native-resolution pixel crop, byte-for-byte PNG copy or first decoded frame of seven MP4 uploads; no resizing, recoloring, repainting or rule changes.",
        "rules_status": "Collection art only. Printed source effects have not been encoded or verified as playable rules.",
        "raw_reference_count": int(inventory["raw_count"]),
        "cards": [],
        "backs": [],
    }
    grouped: dict[str, list[tuple[int, dict]]] = defaultdict(list)
    for index, record in enumerate(records):
        grouped[record["face_job"]].append((index, record))
    staged: dict[int, dict] = {}
    source_count = len(grouped)
    for number, (job_key, items) in enumerate(grouped.items(), 1):
        job = jobs[job_key]
        source_path = Path(job["path"])
        if not source_path.exists():
            if not args.allow_missing:
                raise FileNotFoundError(f"Missing source face: {source_path}")
            for index, record in items:
                staged[index] = _identity_metadata(index, record) | {"available": False, "path": "", "missing_reason": "Source image was unavailable during staging."}
            continue
        source_sha = sha_file(source_path)
        animated_source = False
        decoded_path = source_path
        try:
            with Image.open(source_path) as probe:
                probe.verify()
        except UnidentifiedImageError:
            if source_path.read_bytes()[4:8] != b"ftyp":
                raise
            # Steam stores these seven animated card uploads as MP4 files.
            # Decode the first native frame; do not resize or repaint it.
            animated_source = True
            decoded_path = args.cache / "decoded-card-frames" / (job_key + ".png")
            decoded_path.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source_path), "-frames:v", "1", str(decoded_path)], check=True)
        with Image.open(decoded_path) as atlas:
            source_format = atlas.format
            for index, record in items:
                columns, rows, cell = (int(record[field]) for field in ("columns", "rows", "cell"))
                assert columns > 0 and rows > 0 and 0 <= cell < columns * rows
                # CDN atlases are often 4096 pixels wide, so equal UV tiles
                # have fractional boundaries. Round each boundary separately
                # instead of accumulating truncated widths across the row.
                column, row = cell % columns, cell // columns
                x, y = round(column * atlas.width / columns), round(row * atlas.height / rows)
                right, bottom = round((column + 1) * atlas.width / columns), round((row + 1) * atlas.height / rows)
                width, height = right - x, bottom - y
                assert width > 0 and height > 0
                extracted = atlas.crop((x, y, right, bottom))
                original_pixels = pixel_hash(extracted)
                output = destination / (card_key(record) + ".png")
                original_copy = columns == rows == 1 and source_format == "PNG" and not animated_source
                if original_copy:
                    shutil.copyfile(source_path, output)
                else:
                    extracted.save(output, format="PNG")
                with Image.open(output) as result:
                    assert pixel_hash(result) == original_pixels, f"Card pixels changed: {output.name}"
                staged[index] = _identity_metadata(index, record) | {
                    "available": True,
                    "path": "res://assets/imported/source_cards/" + output.name,
                    "dimensions": [width, height],
                    "sha256": sha_file(output),
                    "pixel_sha256": original_pixels,
                    "source_sha256": source_sha,
                    "source_atlas_dimensions": [atlas.width, atlas.height],
                    "source_cell_rect": [x, y, width, height],
                    "transformation": "first_video_frame_to_png" if animated_source else ("original_png_byte_copy" if original_copy else "lossless_pixel_crop"),
                    "source_animated": animated_source,
                    "animation_playback": False,
                    "atlas_boundary_method": "independently_rounded_normalized_grid",
                }
        print(f"Faces {number}/{source_count}: {len(items)} native cells", flush=True)
    manifest["cards"] = [staged[index] for index in range(len(records))]
    for job_key in sorted({record["back_job"] for record in records}):
        job = jobs[job_key]
        source_path = Path(job["path"])
        if not source_path.exists():
            if not args.allow_missing:
                raise FileNotFoundError(f"Missing source back: {source_path}")
            manifest["backs"].append({"key": job_key, "available": False, "source_url": job["url"], "path": ""})
            continue
        output = destination / (job_key + ".png")
        with Image.open(source_path) as image:
            if image.format == "PNG":
                shutil.copyfile(source_path, output)
                transformation = "original_png_byte_copy"
            else:
                image.save(output, format="PNG")
                transformation = "lossless_format_conversion"
            with Image.open(output) as result:
                assert pixel_hash(image) == pixel_hash(result)
            manifest["backs"].append({
                "key": job_key,
                "available": True,
                "path": "res://assets/imported/source_cards/" + output.name,
                "source_url": job["url"],
                "source_sha256": sha_file(source_path),
                "sha256": sha_file(output),
                "pixel_sha256": pixel_hash(image),
                "dimensions": list(image.size),
                "transformation": transformation,
            })
    counts = Counter(record["kind"] for record in records)
    manifest["counts"] = dict(counts) | {"total": len(records), "available": sum(bool(card["available"]) for card in manifest["cards"])}
    target = args.project / "assets/imported/source_cards.json"
    target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Staged {manifest['counts']} from {source_count} source images.", flush=True)


def _identity_metadata(index: int, record: dict) -> dict:
    return {
        "index": index,
        "key": card_key(record),
        "name": record["name"],
        "raw_name": record["raw_name"],
        "aliases": record.get("names", []),
        "kind": record["kind"],
        "category": record["category"],
        "source_categories": record.get("source_categories", []),
        "source_description": record.get("description", ""),
        "source_face_url": record["face_url"],
        "source_back_url": record["back_url"],
        "source_back_key": record["back_job"],
        "source_card_id": int(record["source_card_id"]),
        "source_atlas_grid": [int(record["columns"]), int(record["rows"])],
        "source_cell": int(record["cell"]),
        "source_paths": record.get("source_paths", [record["source_path"]]),
        "rules_verified": False,
        "playable": False,
    }


if __name__ == "__main__":
    main()
