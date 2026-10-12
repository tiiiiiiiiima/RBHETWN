"""Bounded native MAT0 decoding, including byte alpha and u16 RGB555 arrays."""
import struct
import unittest
from build_ds_material_motion import colour_channel, channel

class SRTTests(unittest.TestCase):
    def test_fx16_uses_twelve_fractional_bits(self):
        data=b'\0'*8+struct.pack('<hhh',0,2048,4096)
        result=channel(data,0,struct.pack('<HBBI',3,0,0x10,8),4,3)
        self.assertEqual(result['values'],[0,0.5,1])

    def test_fx16_and_fx32_have_equal_units(self):
        short=channel(b'\0'*8+struct.pack('<hh',-4096,4096),0,struct.pack('<HBBI',2,0,0x10,8),3,2)
        wide=channel(b'\0'*8+struct.pack('<ii',-4096,4096),0,struct.pack('<HBBI',2,0,0,8),3,2)
        self.assertEqual(short['values'],wide['values'])

    def test_srt_truncated_sample_is_rejected(self):
        with self.assertRaises(AssertionError):
            channel(b'\0'*9,0,struct.pack('<HBBI',3,0,0x10,8),4,3)

class MAT0Tests(unittest.TestCase):
    def test_constant_rgb(self):
        self.assertEqual(colour_channel(b'',0,struct.pack('<I',0x20004a52),0,7)['constant'],0x4a52)

    def test_alpha_is_bytes(self):
        b=b'\0'*8+bytes([0,7,19,31])
        ch=colour_channel(b,0,struct.pack('<I',4<<16|8),4,4)
        self.assertEqual(ch['values'],[0,7,19,31])

    def test_rgb_is_u16(self):
        b=b'\0'*8+struct.pack('<HHH',31,31<<5,31<<10)
        ch=colour_channel(b,0,struct.pack('<I',3<<16|8),0,3)
        self.assertEqual(ch['values'],[31,31<<5,31<<10])

    def test_decimated_alpha_tail(self):
        b=b'\0'*8+bytes([0,10,20,31,9,7])
        ch=colour_channel(b,0,struct.pack('<I',0x80000000|8<<16|8),4,12)
        self.assertEqual(ch['step'],4)
        self.assertEqual(ch['values'],[0,10,20,31,9,7])

    def test_reject_truncated(self):
        with self.assertRaises(AssertionError):
            colour_channel(b'\0'*9,0,struct.pack('<I',4<<16|8),4,4)

    def test_reject_out_of_range_alpha(self):
        with self.assertRaises(AssertionError):
            colour_channel(b'',0,struct.pack('<I',0x20000020),4,4)

    def test_reject_reserved_decimation(self):
        with self.assertRaises(AssertionError):
            colour_channel(b'\0'*32,0,struct.pack('<I',0xc0000008),4,4)

if __name__=='__main__':
    unittest.main()
