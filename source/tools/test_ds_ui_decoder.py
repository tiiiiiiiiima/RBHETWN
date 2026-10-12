#!/usr/bin/env python3
"""Focused independent examples for decoding source DS UI, not game rules."""
import struct
import tempfile
import unittest
from pathlib import Path

from decode_ds_ui import lz10, palette, render_background, render_sprite, tiled_image
from decode_ds_messages import read_message_table


def literals(data):
    result = bytearray(b"\x10" + len(data).to_bytes(3, "little"))
    for p in range(0, len(data), 8):
        result.append(0)
        result.extend(data[p:p + 8])
    return result


class DecoderExamples(unittest.TestCase):
    def test_mes_is_glyph_indices_not_utf16_text(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            codes = [ord(c) - 32 for c in "Dragonoid"] + [0xFF84, ord("I") - 32, 0xFF80]
            encoded = struct.pack("<" + "H" * len(codes), *codes)
            path = root / "sample.mes"
            path.write_bytes(literals(struct.pack("<HHH", 1, 6, len(encoded)) + encoded))
            table = read_message_table(path, root)
            self.assertEqual(table["records"][0]["text"], "Dragonoid I")

    def test_mes_unknown_control_stays_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "sample.mes"
            path.write_bytes(literals(struct.pack("<HHHHH", 1, 6, 4, 0xFF85, 0xFF80)))
            record = read_message_table(path, root)["records"][0]
            self.assertEqual(record["text"], "<0xff85>")
            self.assertEqual(record["unresolved_control_codes"], ["0xff85"])

    def test_mes_bad_pointer_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "sample.mes"
            path.write_bytes(literals(struct.pack("<HHHH", 1, 100, 2, 0xFF80)))
            with self.assertRaisesRegex(ValueError, "outside"):
                read_message_table(path, root)

    def test_lz_literal(self):
        self.assertEqual(lz10(bytes.fromhex("10 04 00 00 00 41 42 43 44")), b"ABCD")

    def test_lz_overlapping_backreference(self):
        self.assertEqual(lz10(bytes.fromhex("10 08 00 00 20 41 42 30 01")), b"ABABABAB")

    def test_invalid_backreference(self):
        with self.assertRaisesRegex(ValueError, "Out-of-bounds"):
            lz10(bytes.fromhex("10 03 00 00 80 00 00"))

    def test_truncated_literal(self):
        with self.assertRaisesRegex(ValueError, "Truncated"):
            lz10(bytes.fromhex("10 04 00 00 00 41"))

    def test_invalid_size(self):
        with self.assertRaisesRegex(ValueError, "Invalid"):
            lz10(bytes.fromhex("10 00 00 00"))

    def test_rgb555_channel_order(self):
        self.assertEqual(palette(bytes.fromhex("1f 00 e0 03 00 7c ff 7f")),
                         [(255, 0, 0, 255), (0, 255, 0, 255),
                          (0, 0, 255, 255), (255, 255, 255, 255)])

    def test_nibble_order_and_transparent_zero(self):
        colors = [(255, 0, 255, 255), (255, 0, 0, 255), (0, 255, 0, 255)]
        image = tiled_image(b"\x21" + b"\0" * 31, 0, 8, 8, 4, colors)
        self.assertEqual(image.getpixel((0, 0)), (255, 0, 0, 255))
        self.assertEqual(image.getpixel((1, 0)), (0, 255, 0, 255))
        self.assertEqual(image.getpixel((2, 0)), (0, 0, 0, 0))

    def test_nce_uses_signed_positions_and_horizontal_flip(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            header = struct.pack("<HHIII", 0, 1, 56, 28, 16)
            cell = struct.pack("<HHHhhH", 0, 4096, 0, -5, -3, 22)
            frame = struct.pack("<IHHIIIII", 0, 1, 4, 0, 4096, 4096, 0, 0)
            (root / "sample_nce.bin").write_bytes(literals(header + cell + frame))
            (root / "sample.nce_ncg1D.bin").write_bytes(literals(b"\x01" + b"\0" * 31))
            (root / "sample_ncl.bin").write_bytes(literals(b"\0\0\x1f\0" + b"\0" * 28))
            images, manifest = render_sprite(root, root / "sample_nce.bin")
            self.assertEqual(manifest["frame_descriptors"][0]["origin"], [-5, -3])
            self.assertEqual(images[0].getpixel((7, 0)), (255, 0, 0, 255))
            self.assertEqual(images[0].getpixel((0, 0)), (0, 0, 0, 0))

    def test_nsc_map_flip_and_screen_crop(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "sample_ncg.bin").write_bytes(literals(b"\x01" + b"\0" * 63))
            (root / "sample_ncl.bin").write_bytes(literals(b"\0\0\x1f\0" + b"\0" * 508))
            (root / "sample_nsc.bin").write_bytes(literals(struct.pack("<H", 1024) + b"\0" * 1534))
            image, _ = render_background(root, root / "sample_nsc.bin")
            self.assertEqual(image.size, (256, 192))
            self.assertEqual(image.getpixel((7, 0)), (255, 0, 0, 255))
            self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 0))


if __name__ == "__main__":
    unittest.main()
