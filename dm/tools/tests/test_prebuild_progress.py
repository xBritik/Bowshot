"""The pipeline prebuild stage gets a count, and from it an ETA, out of the host's own progress lines (nvn_mtl.m pso_prebuild), and the log of a running step is not block-buffered.
No game files needed."""
import contextlib
import importlib.util
import io
import threading
import time
from pathlib import Path
import sys
import tempfile
import textwrap
import types
import unittest
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('build_ipa_from_nsp', REPO / 'scripts/build_ipa_from_nsp.py')
nsp = importlib.util.module_from_spec(spec); spec.loader.exec_module(nsp)
spec_po = importlib.util.spec_from_file_location('pso_offline', REPO / 'dm/gfx/tools/pso_offline.py')
po = importlib.util.module_from_spec(spec_po); spec_po.loader.exec_module(po)

START = '[dm] [nvn-mtl] pipeline prebuild: 42847 shader pairs of /x/shader_pairs.tsv and /x/pso_pairs.tsv, 6 workers (tool)'
STEP = '[dm] [nvn-mtl] pipeline prebuild: 12000 of 42847 pairs, 11800 built, 150 already archived, 0 left to the draws, 0 failed, 95 s'


class PairsProgress(unittest.TestCase):
    def test_start_and_count_lines(self):
        prog = mock.Mock()
        with mock.patch.object(nsp, 'PROG', prog):
            nsp.pairs_progress(START); nsp.pairs_progress(STEP); nsp.pairs_progress('[dm] something else')
        self.assertEqual(prog.set.call_args_list, [mock.call(done=0, total=42847, unit='pairs'), mock.call(done=12000, total=42847, unit='pairs', note='11,800 bases built')])

    def test_the_prewarm_lines_are_not_taken_for_pairs(self):
        prog = mock.Mock()
        with mock.patch.object(nsp, 'PROG', prog):
            nsp.pairs_progress('[dm] [nvn-mtl] pipeline prebuild: 1158 of 8345 prewarm lines, 713 bases compiled, 44 from the archives, 0 failed, 10 s')
        prog.set.assert_not_called()


class BatchProgress(unittest.TestCase):
    def test_ready_groups_are_counted_even_out_of_order(self):
        prog = mock.Mock(); on_line = nsp.pso_batch_progress()
        with mock.patch.object(nsp, 'PROG', prog):
            for line in ('pso_offline: applegpu_g15s: batch 3/292: 1000 bases, compiling or checking cache', 'pso_offline: applegpu_g15s: batch 2/292: ready (compiled)',
                         'pso_offline: applegpu_g15s: batch 3/292: ready (reused)', 'pso_offline: applegpu_g15s: merging 292 batches'): on_line(line)
        self.assertEqual([c.kwargs['done'] for c in prog.set.call_args_list], [0, 1, 2]); self.assertEqual({c.kwargs['total'] for c in prog.set.call_args_list}, {292})


class BasesJobs(unittest.TestCase):
    def run_batches(self, bases_jobs):
        d = Path(tempfile.mkdtemp()); self.addCleanup(__import__('shutil').rmtree, d, ignore_errors=True)
        live, peak, lock = [0], [0], threading.Lock()
        def fake(lib_dir, group, folder, *a, **k):
            with lock: live[0] += 1; peak[0] = max(peak[0], live[0])
            time.sleep(0.15 if group and group[0] == 'b0' else 0.02)   # the first group is the slowest: the pieces must still come out in the groups' order
            with lock: live[0] -= 1
            piece = d / f'{folder.name}.mtl4a'; piece.write_bytes(b'x'); return piece, False
        merged = []
        def fake_run(cmd, **k):
            merged.extend(Path(x).name for x in cmd if str(x).endswith('.mtl4a') and 'pieces' not in str(x)); (d / 'out.mtl4a').write_bytes(b'm')
            return types.SimpleNamespace(returncode=0)
        bases = [f'b{i}' for i in range(5)]
        with mock.patch.object(po, 'compile_batch', fake), mock.patch.object(po.subprocess, 'run', fake_run), mock.patch.object(po.vol_space, 'free_bytes', return_value=1 << 40), contextlib.redirect_stdout(io.StringIO()):
            po.compile_batches(d, bases, d, d / 'out.mtl4a', 'applegpu_g15s', 'macos', '27.0', 'tv', 1, bases_jobs=bases_jobs)
        return peak[0], [m for m in merged if m != 'out.mtl4a']

    def test_groups_run_at_a_time_and_merge_in_order(self):
        peak1, order1 = self.run_batches(1); peak2, order2 = self.run_batches(2)
        self.assertEqual(peak1, 1); self.assertEqual(peak2, 2)
        self.assertEqual(order1, order2); self.assertEqual(order2, [f'0000{i}.mtl4a' for i in range(1, 6)])


class LiveLog(unittest.TestCase):
    def test_the_log_of_a_running_step_can_be_read_while_it_runs(self):
        d = Path(tempfile.mkdtemp()); self.addCleanup(__import__('shutil').rmtree, d, ignore_errors=True)
        script = d / 'host.py'
        script.write_text(textwrap.dedent('''
            import sys, time
            print("first line", flush=True)
            time.sleep(2.5)
            print("last line", flush=True)'''))
        log, seen = d / 'step.log', []
        def on_line(line):
            if line == 'last line': seen.append(log.read_text())   # when the second line arrives, the first has been written to the file
        with mock.patch.object(nsp, 'PROG', mock.Mock()):
            nsp.run([sys.executable, str(script)], log, on_line=on_line)
        self.assertEqual(len(seen), 1); self.assertIn('first line', seen[0])


if __name__ == '__main__':
    unittest.main()
