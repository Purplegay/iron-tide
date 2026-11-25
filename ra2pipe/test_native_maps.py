"""Small format fixtures independent of installed retail data."""
import struct
import unittest
import tempfile
from pathlib import Path
from native_maps import ini, lcw, iso_records, fill_clear_cells, tile


class MapFormatTests(unittest.TestCase):
    def test_bridge_extra_pixels_follow_flattened_road_plane(self):
        # Two native TMP subtiles: road at height 4, pillar at water height 0.
        # Each has one extra pixel at its own tile origin and a normal Z block.
        blocks=[]
        for level in [4, 0]:
            header=bytearray(52)
            struct.pack_into('<iiii',header,20,0,0,1,1)
            struct.pack_into('<I',header,36,3)
            header[40]=level
            blocks.append(bytes(header)+bytes([1])*900+bytes(900)+bytes([1,0]))
        data=struct.pack('<IIIIII',2,1,60,30,24,24+len(blocks[0]))+b''.join(blocks)
        palette=[(0,0,0),(255,128,32)]+[(0,0,0)]*254
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in ['Ovrps07.tem','Ovrpsb07.tem','WCliff28.tem']:
                (root/name).write_bytes(data)
                road=tile(root,{'name':name},0,palette,24)
                pillar=tile(root,{'name':name},1,palette,24)
                self.assertEqual(road[3][:2],(0,0))
                self.assertEqual(pillar[3][:2],(0,60 if name.startswith('Ovrps') else 0))
                self.assertEqual(pillar[3][2].getpixel((0,0)),(255,128,32,255))
                self.assertEqual(road[2].tobytes(),pillar[2].tobytes())

    def test_sparse_iso_records_and_default_clear_cells(self):
        cell = (2, 1, 7, 0, 3, 0)
        self.assertEqual(iso_records(struct.pack('<HHIBBB', *cell) + bytes(4)), [cell])
        rows = fill_clear_cells([cell], 2, 2)
        self.assertEqual(rows[0], cell)
        self.assertEqual(len(rows), 6)
        self.assertEqual(len({r[:2] for r in rows}), 6)
        self.assertTrue(all(r[2:] == (65535, 0, 0, 0) for r in rows[1:]))
        self.assertEqual(fill_clear_cells(rows, 2, 2), rows)

    def test_invalid_iso_tail_and_duplicate_cells_rejected(self):
        cell = struct.pack('<HHIBBB', 2, 1, 0, 0, 0, 0)
        for data in [cell + b'X', cell + b'bad!', cell + cell, b'']:
            with self.assertRaises(ValueError): iso_records(data)

    def test_overlay_type_indices_follow_insertion_order(self):
        data=ini('[OverlayTypes]\n1=BRIDGE1\n3=TIB01\n9=GEM01\n')
        self.assertEqual(dict(enumerate(data['OverlayTypes'].values())),{0:'BRIDGE1',1:'TIB01',2:'GEM01'})

    def test_base64_double_slash_is_not_an_ini_comment(self):
        self.assertEqual(ini('[PreviewPack]\n1=AAAA//AA==\n')['PreviewPack']['1'],'AAAA//AA==')

    def test_lcw_literal_and_terminator(self):
        self.assertEqual(lcw(bytes([131])+b'abc'+bytes([128]),3),b'abc')

    def test_lcw_overlapping_relative_reference(self):
        self.assertEqual(lcw(bytes([129])+b'a'+bytes([0x10,1,128]),5),b'aaaaa')

    def test_lcw_fill(self):
        self.assertEqual(lcw(bytes([254])+struct.pack('<H',5)+b'Z'+bytes([128]),5),b'ZZZZZ')

    def test_truncated_output_rejected(self):
        with self.assertRaises(ValueError):lcw(bytes([129,1,128]),2)

    def test_invalid_back_reference_rejected(self):
        with self.assertRaises(ValueError):lcw(bytes([0,1,128]),3)


if __name__=='__main__':unittest.main()
