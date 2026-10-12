"""Bounded native placement records, using a known source pad as the fixture."""
import struct
import unittest
from build_ds_field_objects import parse_placements

class SetDataTests(unittest.TestCase):
    def record(self,kind=5):
        return struct.pack('<6i3H2B',25*4096,2*4096,123*4096,
                           14*4096,4096,22*4096,0,16384,0,0,kind)

    def test_native_pad_units_rotation_and_type(self):
        r=parse_placements(struct.pack('<HH',0,1)+self.record())['records'][0]
        self.assertEqual(r['position'],[25,2,123])
        self.assertEqual(r['extent'],[14,1,22])
        self.assertEqual(r['rotation_u16'],[0,16384,0])
        self.assertEqual(r['kind'],'speed_pad')

    def test_empty_source_tutorial_set(self):
        self.assertEqual(parse_placements(b'\0'*4)['count'],0)

    def test_unknown_types_are_retained_without_guessed_behavior(self):
        r=parse_placements(struct.pack('<HH',0,1)+self.record(82))['records'][0]
        self.assertEqual((r['type_id'],r['kind']),(82,'unsupported'))

    def test_truncated_header(self):
        with self.assertRaises(ValueError): parse_placements(b'\0'*3)

    def test_count_mismatch(self):
        with self.assertRaises(ValueError): parse_placements(struct.pack('<HH',0,2)+self.record())

    def test_trailing_unbounded_data(self):
        with self.assertRaises(ValueError): parse_placements(struct.pack('<HH',0,1)+self.record()+b'\0')

    def test_invalid_extent(self):
        b=bytearray(struct.pack('<HH',0,1)+self.record())
        struct.pack_into('<i',b,4+12,-4096)
        with self.assertRaises(ValueError): parse_placements(bytes(b))

if __name__=='__main__': unittest.main()
