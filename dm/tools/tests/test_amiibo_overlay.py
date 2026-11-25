import sys, tempfile, unittest, zlib, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
import oot_amiibo_overlay as ov
T = ov.T


def sample():   # the shape of Game/AmiiboSetting: entries with a drop chance range, a daily limit that is unset (on) or already off
    def entry(name, lo, hi, limit):
        e = {'Name': T(0xA0, name), 'DropActorInfoList': {'MinNumberOfDropChance': T(0xD1, lo), 'MaxNumberOfDropChance': T(0xD1, hi)}}
        if limit is not None: e['EnableDailyLimit'] = T(0xD0, limit)
        return e
    return {'AmiiboDropActorSettingSet': [entry('a', 3, 5, None), entry('b', 1, 1, 0), entry('c', 3, 5, 1)]}


class Overlay(unittest.TestCase):
    def test_byml_round_trip_is_byte_for_byte(self):
        blob = ov.write(7, sample())
        ver, data = ov.parse(blob)
        self.assertEqual(ver, 7); self.assertEqual(data, sample()); self.assertEqual(ov.write(ver, data), blob)

    def test_the_daily_limit_goes_off_for_every_entry_and_nothing_else_changes(self):
        v = ov.variant(sample(), 1, 0)
        self.assertTrue(all(e['EnableDailyLimit'] == T(0xD0, 0) for e in v['AmiiboDropActorSettingSet']))
        self.assertEqual([e['DropActorInfoList'] for e in v['AmiiboDropActorSettingSet']], [e['DropActorInfoList'] for e in sample()['AmiiboDropActorSettingSet']])
        ver, back = ov.parse(ov.write(7, v)); self.assertEqual(back, v)

    def test_a_rewritten_file_is_not_bigger_than_the_game_sizes_its_heap_for(self):
        orig = ov.write(7, sample()); new = ov.write(7, ov.variant(sample(), 1, 0))
        self.assertLessEqual(len(new), len(orig) + 64)

    def test_resource_size_table_entry_is_doubled(self):
        d = bytearray(b'REST' + b'\0' * 60); key = struct.pack('<I', zlib.crc32(ov.PATH.encode()))
        d[16:20] = key; struct.pack_into('<I', d, 20, 2000)
        z, before, after = ov.rstb_raise(ov.zstd.compress(bytes(d)))
        out = ov.zstd.decompress(z); self.assertEqual((before, after), (2000, 4000)); self.assertEqual(struct.unpack_from('<I', out, 20)[0], 4000)

    def test_reader_takes_an_extracted_folder(self):
        d = Path(tempfile.mkdtemp()); self.addCleanup(lambda: __import__('shutil').rmtree(d, ignore_errors=True))
        (d / 'Game').mkdir(); (d / 'Game/x.bin').write_bytes(b'hello')
        self.assertEqual(ov.reader(str(d))('Game/x.bin'), b'hello')


if __name__ == '__main__':
    unittest.main()
