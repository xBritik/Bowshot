import sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import bowshot_report as report

LINES = """Engine revision: bowshot-0.1.2-nxnative-0293739d
[18:30:50] [1/4] unpack v131072 ...
[18:31:04] ✓ [1/4] unpack v131072 (0:14): 24.4 GB, reused (image checked)
[18:32:18] ✓ [2/5] rewrite (0:55): main, subsdk0, sdk
[18:32:57] ✓ [3/5] shader split (1:39): 42,847 shaders
[20:10:00] ✓ [4/5] Mac shaders (1:17:03): 42,847 Mac libraries
[20:10:05] [1/3] Mac app ...
[20:12:05] ✗ [1/3] Mac app (2:00): boom
[20:12:06] [RED] something
"""


class Report(unittest.TestCase):
    def log(self, text):
        d = tempfile.mkdtemp(); self.addCleanup(lambda: __import__('shutil').rmtree(d, ignore_errors=True))
        p = Path(d) / 'build.log'; p.write_text(text, encoding='utf-8'); return p

    def test_steps_states_parts_and_times(self):
        r = report.parse(self.log(LINES))
        self.assertEqual([(s['part'], s['step'], s['state'], s['seconds']) for s in r['steps']],
                         [(1, 'unpack v131072', 'reused', 14), (1, 'rewrite', 'made', 55), (1, 'shader split', 'made', 99), (1, 'Mac shaders', 'made', 4623), (2, 'Mac app', 'failed', 120)])
        self.assertEqual(r['revision'], 'bowshot-0.1.2-nxnative-0293739d')
        self.assertEqual(r['warnings'], 1)
        self.assertEqual(r['wall_s'], 20 * 3600 + 12 * 60 + 6 - (18 * 3600 + 30 * 60 + 50))

    def test_past_midnight(self):
        r = report.parse(self.log('[23:59:00] ✓ [1/2] a (0:30)\n[00:01:00] ✓ [2/2] b (0:30)\n'))
        self.assertEqual(r['wall_s'], 120)

    def test_json_events_from_the_builder_window(self):
        r = report.parse(self.log('{"ev":"stage_end","name":"rewrite","ok":true,"summary":"kept","elapsed":12.4,"t":10}\n{"ev":"bowshot_part","name":"Game app"}\n'
                                  '{"ev":"stage_end","name":"Mac app","ok":true,"summary":"","elapsed":3,"t":40}\n'))
        self.assertEqual([(s['part'], s['state']) for s in r['steps']], [(1, 'reused'), (2, 'made')])
        self.assertEqual(r['wall_s'], 30)

    def test_record_and_compare(self):
        a, b = self.log(LINES.replace('(0:55)', '(0:55)')), self.log(LINES.replace('✓ [1/4] unpack v131072 (0:14): 24.4 GB, reused (image checked)', '✓ [1/4] unpack v131072 (9:14): 24.4 GB').replace('(1:39)', '(0:20)'))
        out = Path(tempfile.mkdtemp()); self.addCleanup(lambda: __import__('shutil').rmtree(out, ignore_errors=True))
        for name, p in (('A', a), ('B', b)):
            sys.argv = ['x', 'record', str(p), '--id', name, '--dir', str(out)]; self.assertEqual(report.main(), 0)
        sys.argv = ['x', 'record', str(a), '--id', 'A', '--dir', str(out)]
        with self.assertRaises(SystemExit): report.main()   # an id is used once
        text = report.compare('', '', out)
        self.assertIn('reused → made', text); self.assertIn('Reused before, made now: unpack v131072', text); self.assertIn('shader split', text)
        self.assertTrue((out / 'reports' / 'A.md').is_file())


    def test_the_versions_come_from_the_tree_the_build_was_made_from(self):
        d = Path(tempfile.mkdtemp()); self.addCleanup(lambda: __import__('shutil').rmtree(d, ignore_errors=True))
        (d / 'dm/gfx/nvn').mkdir(parents=True); (d / 'VERSION').write_text('0.1.1\n'); (d / 'UPSTREAM-REVISION').write_text('bowshot-0.1.0-nxnative-8c94bd1e\n')
        (d / 'dm/gfx/nvn/dmsh_chain.h').write_text('#define DMSH_CHAIN "e52917b72fcf"\n')
        self.assertEqual(report.versions(d), {'version': '0.1.1', 'revision': 'bowshot-0.1.0-nxnative-8c94bd1e', 'chain': 'e52917b72fcf'})
        self.assertNotEqual(report.versions(d), report.versions())


if __name__ == '__main__':
    unittest.main()
