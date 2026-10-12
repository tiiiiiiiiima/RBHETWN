#!/usr/bin/env python3
"""Read the bounded English glyph-index MES tables in the supplied DS dump.

Unknown control codes stay explicit; this does not interpret scripts or alter
game rules. The original code units and source hashes are retained.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from decode_ds_ui import lz10


TABLES = ("mes_BakuganName.mes", "mes_CardName.mes", "mes_CardText.mes")


def read_message_table(path: Path, root: Path) -> dict:
    compressed = path.read_bytes()
    data = lz10(compressed)
    if len(data) < 2:
        raise ValueError("Truncated MES count")
    count = struct.unpack_from("<H", data)[0]
    table_end = 2 + count * 4
    if not 0 < count <= 4096 or table_end > len(data):
        raise ValueError("Invalid MES table extent")
    records = []
    for index in range(count):
        offset, size = struct.unpack_from("<HH", data, 2 + index * 4)
        if offset < table_end or size % 2 or offset + size > len(data):
            raise ValueError("MES string points outside bounded glyph data")
        codes = [value[0] for value in struct.iter_unpack("<H", data[offset:offset + size])]
        text = []
        unresolved = []
        for code in codes:
            if 0 <= code <= 94:
                text.append(chr(code + 32))
            elif code == 0xFF84:
                text.append(" ")
            elif code == 0xFF80:
                continue
            else:
                unresolved.append(f"0x{code:04x}")
                text.append(f"<0x{code:04x}>")
        records.append({"index": index, "text": "".join(text), "offset": offset,
                        "size_bytes": size, "code_units": codes,
                        "unresolved_control_codes": sorted(set(unresolved))})
    return {"source_path": str(path.relative_to(root)),
            "source_sha256": hashlib.sha256(compressed).hexdigest(),
            "decompressed_sha256": hashlib.sha256(data).hexdigest(),
            "format": "LZ10 + uint16 count + uint16 offset/byte-size records + English glyph indices",
            "language": "English base files (no localization suffix)",
            "records": records}


def decode_message_tables(raw_root: Path) -> dict:
    return {name: read_message_table(raw_root / "font" / name, raw_root) for name in TABLES}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = {"schema": 1, "source_game": "Bakugan Battle Brawlers DS / supplied user archive",
              "tables": decode_message_tables(args.raw_root),
              "limits": "Glyphs decoded; control codes and game effect logic are not executed."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({name: len(table["records"]) for name, table in result["tables"].items()}))


if __name__ == "__main__":
    main()
