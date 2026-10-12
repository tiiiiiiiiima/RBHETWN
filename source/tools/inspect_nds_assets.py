#!/usr/bin/env python3
"""Inventory a user-provided Nintendo DS ROM without running or importing it.

Examples:
  python3 tools/inspect_nds_assets.py /tmp/game.nds > /tmp/game-inventory.json
  python3 tools/inspect_nds_assets.py /tmp/game.zip --extract /tmp/ds-assets \
      --manifest /tmp/game-inventory.json

ZIP input must contain exactly one .nds member. Extraction copies raw NitroFS
files only, into a new staging directory outside this game project. It does not
convert models, execute ROM code, or write anything into the game's assets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mmap
import shutil
import struct
import sys
import tempfile
import zipfile
from contextlib import contextmanager
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MAX_ROM_BYTES = 512 * 1024 * 1024
NITRO_SIGNATURES = {
    b"BMD0": ("nsbmd", "3d_model"),
    b"BTX0": ("nsbtx", "3d_texture"),
    b"BCA0": ("nsbca", "3d_skeletal_animation"),
    b"BTA0": ("nsbta", "3d_texture_animation"),
    b"BTP0": ("nsbtp", "3d_texture_pattern_animation"),
    b"BVA0": ("nsbva", "3d_visibility_animation"),
    b"NARC": ("narc", "archive"),
    b"RGCN": ("ncgr", "2d_graphics"),
    b"RLCN": ("nclr", "2d_palette"),
    b"RCSN": ("nscr", "2d_screen"),
    b"RECN": ("ncer", "2d_cells"),
    b"RNAN": ("nanr", "2d_animation"),
    b"RCMN": ("nmcr", "2d_multicell"),
    b"RAMN": ("nmar", "2d_multicell_animation"),
    b"SDAT": ("sdat", "sound_archive"),
    b"SSEQ": ("sseq", "sound_sequence"),
    b"SSAR": ("ssar", "sound_sequence_archive"),
    b"SWAR": ("swar", "sound_wave_archive"),
    b"SWAV": ("swav", "sound_wave"),
    b"SBNK": ("sbnk", "sound_bank"),
    b"STRM": ("strm", "sound_stream"),
}


class InventoryError(ValueError):
    """An input or output failed a structural or staging check."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@contextmanager
def open_rom(source: Path):
    if source.suffix.lower() == ".nds":
        yield source, None
        return
    if not zipfile.is_zipfile(source):
        raise InventoryError("Input must be an .nds ROM or a ZIP containing one .nds ROM.")
    with zipfile.ZipFile(source) as archive:
        members = [item for item in archive.infolist()
                   if not item.is_dir() and Path(item.filename).suffix.lower() == ".nds"]
        if len(members) != 1:
            raise InventoryError(f"ZIP must contain exactly one .nds member; found {len(members)}.")
        member = members[0]
        if member.flag_bits & 1:
            raise InventoryError("Encrypted ZIP members are not supported.")
        if not 0x200 <= member.file_size <= MAX_ROM_BYTES:
            raise InventoryError("ZIP ROM size must be between 512 bytes and 512 MiB.")
        # Do not extract archive paths: stream this one member to a fixed name.
        with tempfile.TemporaryDirectory(prefix="nds-inventory-") as temp_dir:
            rom_path = Path(temp_dir) / "input.nds"
            copied = 0
            with archive.open(member) as incoming, rom_path.open("xb") as outgoing:
                while chunk := incoming.read(1024 * 1024):
                    copied += len(chunk)
                    if copied > MAX_ROM_BYTES or copied > member.file_size:
                        raise InventoryError("ZIP ROM exceeded its declared size or the 512 MiB limit.")
                    outgoing.write(chunk)
            if copied != member.file_size:
                raise InventoryError("ZIP ROM does not match its declared size.")
            yield rom_path, member.filename


def check_extent(offset: int, size: int, limit: int, label: str) -> None:
    if offset < 0 or size < 0 or offset > limit or size > limit - offset:
        raise InventoryError(f"{label} lies outside its containing data.")


def safe_component(raw: bytes) -> str:
    if not raw or raw in (b".", b"..") or any(c in raw for c in (b"/", b"\\", b"\0")):
        raise InventoryError("NitroFS contains an unsafe path component.")
    if any(byte < 32 or byte == 127 for byte in raw):
        raise InventoryError("NitroFS contains a control character in a path.")
    return raw.decode("latin-1")


def parse_filenames(data, offset: int, size: int, file_count: int) -> dict[int, str]:
    check_extent(offset, size, len(data), "FNT")
    if size < 8:
        raise InventoryError("FNT is smaller than its root directory record.")
    directory_count = struct.unpack_from("<H", data, offset + 6)[0]
    if not 1 <= directory_count <= 4096 or directory_count * 8 > size:
        raise InventoryError("FNT directory count is invalid.")
    directories = [struct.unpack_from("<IHH", data, offset + i * 8)
                   for i in range(directory_count)]
    for subtable, _, _ in directories:
        if not directory_count * 8 <= subtable < size:
            raise InventoryError("FNT directory subtable overlaps its directory table or exceeds FNT.")
    names: dict[int, str] = {}
    visited: set[int] = set()
    pending = [(0, "")]
    while pending:
        directory_index, parent_path = pending.pop()
        if directory_index in visited:
            raise InventoryError("FNT contains a repeated or cyclic directory reference.")
        visited.add(directory_index)
        subtable, file_id, _ = directories[directory_index]
        cursor = offset + subtable
        used_names: set[str] = set()
        while True:
            check_extent(cursor, 1, offset + size, "FNT entry")
            marker = data[cursor]
            cursor += 1
            if marker == 0:
                break
            name_size = marker & 0x7F
            if not name_size:
                raise InventoryError("FNT entry has an empty name.")
            check_extent(cursor, name_size, offset + size, "FNT name")
            name = safe_component(bytes(data[cursor:cursor + name_size]))
            cursor += name_size
            if name in used_names:
                raise InventoryError("FNT directory contains duplicate names.")
            used_names.add(name)
            full_path = f"{parent_path}/{name}" if parent_path else name
            if marker & 0x80:
                check_extent(cursor, 2, offset + size, "FNT child directory ID")
                child_id = struct.unpack_from("<H", data, cursor)[0]
                cursor += 2
                child_index = child_id - 0xF000
                if not 0 <= child_index < directory_count:
                    raise InventoryError("FNT child directory ID is outside its directory table.")
                if directories[child_index][2] != 0xF000 + directory_index:
                    raise InventoryError("FNT child directory has an inconsistent parent ID.")
                pending.append((child_index, full_path))
            else:
                if file_id >= file_count or file_id in names:
                    raise InventoryError("FNT file ID is outside FAT or appears more than once.")
                names[file_id] = full_path
                file_id += 1
    if len(visited) != directory_count:
        raise InventoryError("FNT contains unreachable directories.")
    return names


def lz_preview(raw: bytes, kind: int, declared_size: int, header_size: int) -> bytes:
    """Decode at most 64 output bytes to identify compressed Nitro signatures."""
    goal = min(64, declared_size)
    output = bytearray()
    cursor = header_size

    def take(count: int) -> bytes:
        nonlocal cursor
        if cursor + count > len(raw):
            raise InventoryError("Compressed preview is truncated.")
        result = raw[cursor:cursor + count]
        cursor += count
        return result

    while len(output) < goal:
        flags = take(1)[0]
        for bit in range(7, -1, -1):
            if len(output) >= goal:
                break
            if not (flags >> bit) & 1:
                output.extend(take(1))
                continue
            first, second = take(2)
            if kind == 0x10:
                length = (first >> 4) + 3
                distance = ((first & 15) << 8 | second) + 1
            elif first >> 4 == 0:
                third = take(1)[0]
                length = ((first & 15) << 4 | second >> 4) + 0x11
                distance = ((second & 15) << 8 | third) + 1
            elif first >> 4 == 1:
                third, fourth = take(2)
                length = ((first & 15) << 12 | second << 4 | third >> 4) + 0x111
                distance = ((third & 15) << 8 | fourth) + 1
            else:
                length = (first >> 4) + 1
                distance = ((first & 15) << 8 | second) + 1
            if distance > len(output) or length > declared_size - len(output):
                raise InventoryError("Compressed preview contains an invalid back-reference.")
            for _ in range(min(length, goal - len(output))):
                output.append(output[-distance])
    return bytes(output)


def identify(data, start: int, end: int) -> dict:
    # 128 source bytes suffice for a 64-byte literal-only LZ preview.
    prefix = bytes(data[start:min(end, start + 128)])
    result = {"signature_hex": prefix[:4].hex(), "format": "unknown", "kind": "unknown"}
    signature = prefix[:4]
    if len(prefix) >= 4 and prefix[0] in (0x10, 0x11):
        size = int.from_bytes(prefix[1:4], "little")
        header_size = 4
        if prefix[0] == 0x11 and size == 0 and len(prefix) >= 8:
            size = int.from_bytes(prefix[4:8], "little")
            header_size = 8
        result["possible_compression"] = f"lz{prefix[0]:02x}"
        result["declared_decompressed_size"] = size
        if size:
            try:
                preview = lz_preview(prefix, prefix[0], size, header_size)
                signature = preview[:4]
                result["decompressed_signature_hex"] = signature.hex()
                result["compression_preview_valid"] = True
            except InventoryError as error:
                result["compression_preview_valid"] = False
                result["compression_preview_note"] = str(error)
    if signature in NITRO_SIGNATURES:
        result["format"], result["kind"] = NITRO_SIGNATURES[signature]
    return result


def inspect_rom(data, source_path: Path, member_name: str | None) -> dict:
    if not 0x200 <= len(data) <= MAX_ROM_BYTES:
        raise InventoryError("ROM size must be between 512 bytes and 512 MiB.")
    fnt_offset, fnt_size, fat_offset, fat_size = struct.unpack_from("<IIII", data, 0x40)
    if not fat_size or fat_size % 8:
        raise InventoryError("FAT must contain a positive whole number of 8-byte records.")
    if fnt_offset < 0x200 or fat_offset < 0x200:
        raise InventoryError("NitroFS tables overlap the base ROM header.")
    check_extent(fnt_offset, fnt_size, len(data), "FNT")
    check_extent(fat_offset, fat_size, len(data), "FAT")
    if max(fnt_offset, fat_offset) < min(fnt_offset + fnt_size, fat_offset + fat_size):
        raise InventoryError("FNT and FAT overlap.")
    file_count = fat_size // 8
    if file_count > 65536:
        raise InventoryError("FAT file count exceeds the 16-bit NitroFS file ID range.")
    filenames = parse_filenames(data, fnt_offset, fnt_size, file_count)
    manifest = []
    totals: dict[str, int] = {}
    used_paths = set(filenames.values())
    for file_id in range(file_count):
        start, end = struct.unpack_from("<II", data, fat_offset + file_id * 8)
        if end < start:
            raise InventoryError(f"FAT file {file_id} has reversed offsets.")
        check_extent(start, end - start, len(data), f"FAT file {file_id}")
        path = filenames.get(file_id, f"__unnamed_file_ids__/{file_id:05d}.bin")
        if file_id not in filenames and path in used_paths:
            raise InventoryError("Generated unnamed file path conflicts with a named file.")
        kind = identify(data, start, end)
        totals[kind["kind"]] = totals.get(kind["kind"], 0) + 1
        digest = hashlib.sha256()
        for offset in range(start, end, 1024 * 1024):
            digest.update(data[offset:min(offset + 1024 * 1024, end)])
        manifest.append({"file_id": file_id, "path": path, "named_in_fnt": file_id in filenames,
                         "offset": start, "size_bytes": end - start, "sha256": digest.hexdigest(),
                         **kind})
    decode_header = lambda start, length: bytes(data[start:start + length]).rstrip(b"\0 ").decode("ascii", "replace")
    return {
        "schema_version": 1,
        "inspection_scope": "raw NitroFS inventory; signature identification only; no game asset import",
        "source": {"path": str(source_path), "sha256": sha256_file(source_path), "zip_member": member_name},
        "rom": {"title": decode_header(0, 12), "game_code": decode_header(12, 4),
                "maker_code": decode_header(16, 2), "unit_code": data[18],
                "size_bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()},
        "nitrofs": {"fnt_offset": fnt_offset, "fnt_size": fnt_size, "fat_offset": fat_offset,
                    "fat_size": fat_size, "file_count": file_count,
                    "named_file_count": len(filenames), "kind_counts": totals},
        "files": manifest,
        "limitations": ["This tool does not inspect nested NARC archives or overlay/ARM binaries.",
                        "LZ10/LZ11 checks decode a short prefix only; they do not validate a whole stream.",
                        "A recognized signature does not prove that a model or texture can be converted."],
    }


def staging_path(value: str, label: str) -> Path:
    path = Path(value).expanduser().resolve()
    if path == PROJECT_ROOT or PROJECT_ROOT in path.parents:
        raise InventoryError(f"{label} must be outside this game project; use a staging path such as /tmp/ds-assets.")
    if path.exists():
        raise InventoryError(f"{label} already exists; choose a new path to avoid overwriting files.")
    if not path.parent.is_dir():
        raise InventoryError(f"{label} parent directory does not exist.")
    return path


def extract_raw(data, manifest: dict, output: Path) -> None:
    output.mkdir()
    try:
        for entry in manifest["files"]:
            destination = output.joinpath(*entry["path"].split("/"))
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("xb") as handle:
                end = entry["offset"] + entry["size_bytes"]
                for offset in range(entry["offset"], end, 1024 * 1024):
                    handle.write(data[offset:min(offset + 1024 * 1024, end)])
    except Exception:
        # Only remove the new directory created by this invocation.
        shutil.rmtree(output)
        raise
    manifest["extraction"] = {"directory": str(output), "mode": "raw_files_only", "file_count": len(manifest["files"])}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="User-provided .nds ROM or a ZIP containing exactly one .nds ROM")
    parser.add_argument("--extract", help="Optional new staging directory outside the game project")
    parser.add_argument("--manifest", help="Optional new JSON file outside the game project; default: stdout")
    args = parser.parse_args(argv)
    try:
        source = args.source.expanduser().resolve(strict=True)
        extraction = staging_path(args.extract, "Extraction directory") if args.extract else None
        manifest_path = staging_path(args.manifest, "Manifest path") if args.manifest else None
        if extraction and manifest_path and extraction == manifest_path:
            raise InventoryError("Extraction directory and manifest file must differ.")
        with open_rom(source) as (rom_path, member_name):
            if not 0x200 <= rom_path.stat().st_size <= MAX_ROM_BYTES:
                raise InventoryError("ROM size must be between 512 bytes and 512 MiB.")
            with rom_path.open("rb") as handle, mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as data:
                manifest = inspect_rom(data, source, member_name)
                if extraction:
                    extract_raw(data, manifest, extraction)
                rendered = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
                if manifest_path:
                    with manifest_path.open("x", encoding="utf-8") as output:
                        output.write(rendered)
                    print(f"Inventoried {len(manifest['files'])} NitroFS files; manifest: {manifest_path}", file=sys.stderr)
                else:
                    sys.stdout.write(rendered)
        return 0
    except (InventoryError, OSError, zipfile.BadZipFile, RuntimeError) as error:
        print(f"DS inventory failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
