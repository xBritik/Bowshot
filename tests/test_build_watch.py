import json, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import bowshot_watch as watch

LINES = """[18:30:50] [1/4] unpack v131072 ...
[18:31:04] ✓ [1/4] unpack v131072 (0:14): 24.4 GB, reused (image checked)
[18:32:58] [4/5] Mac shaders …
[18:42:38] [4/5] Mac shaders · compiling: 25%, 10,671/42,847 shaders, 42,847 not cached, 9:39 · ETA 37:55
"""


class Watch(unittest.TestCase):
    def test_the_current_step_of_a_terminal_build(self):
        c = watch.live_step(LINES.split('\n'))
        self.assertEqual((c['name'], c['step'], c['pct'], c['eta']), ('Mac shaders', 'compiling', 25, 'about 37:55 left'))
        self.assertIn('10,671/42,847 shaders', c['detail'])

    def test_between_steps_there_is_none(self):
        self.assertIsNone(watch.live_step((LINES + '[18:50:00] ✓ [4/5] Mac shaders (17:02): 42,847 shaders\n').split('\n')))

    def test_a_step_that_logs_only_its_time(self):
        c = watch.live_step('[19:10:17] [6/6] Pipeline prebuild · building: 0:30'.split('\n'))
        self.assertEqual((c['name'], c['step'], c['pct']), ('Pipeline prebuild', 'building', None))

    def test_json_events_from_the_builder_window(self):
        ev = [{'ev': 'stage', 'k': 2, 'n': 5, 'name': 'rewrite', 'step': ''}, {'ev': 'progress', 'frac': 0.5, 'done': 1, 'total': 2, 'unit': 'modules', 'note': '', 'eta': 90}]
        c = watch.live_step([json.dumps(e) for e in ev])
        self.assertEqual((c['name'], c['pct'], c['eta']), ('rewrite', 50, 'about 1:30 left')); self.assertIn('1/2 modules', c['detail'])

    def test_status_of_a_finished_build(self):
        d = Path(tempfile.mkdtemp()); self.addCleanup(__import__('shutil').rmtree, d, ignore_errors=True)
        (d / 'Bowshot-build').mkdir(); log = d / 'Bowshot-build' / 'build.log'
        log.write_text(LINES + '[19:00:00] ✓ [4/5] Mac shaders (17:02): 42,847 shaders\nREADY: /Applications/Game.app\n')
        self.assertEqual(watch.find_log(d), log)
        s = watch.status(log, d, watch.Pace())
        self.assertEqual(s['finished'], '/Applications/Game.app'); self.assertIsNone(s['current'])
        self.assertEqual([(x['name'], x['state']) for x in s['steps']], [('unpack v131072', 'reused'), ('Mac shaders', 'made')])


if __name__ == '__main__':
    unittest.main()
