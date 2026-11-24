#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# What a build did and how long each step took, from its build.log, and a comparison between builds (Bowshot versions, engine revisions, machines).
#   bowshot_report.py report  <build.log> [--out report.md]      the build as Markdown (steps, reused or made, times, the machine and the versions); bowshot_build.sh writes one
#                                                                 into the build folder after every build (Bowshot-build/build-report.md)
#   bowshot_report.py record  <build.log> --id ID [--note TEXT] [--dir docs/builds] [--date YYYY-MM-DD]
#                                                                 keeps the build in the repository's history: docs/builds/builds.tsv (one row), steps.tsv (one row per step)
#                                                                 and reports/<id>.md. An id is used once
#   bowshot_report.py compare [A B] [--dir docs/builds]           two recorded builds side by side (default: the last two): each step's time and state, the totals, what got slower or
#                                                                 was reused and is now made again, and what differs between the two machines and chains (a comparison of unlike builds says so)
# The log is the one bowshot_build.sh writes: the engine's lines ("[18:31:04] ✓ [1/4] unpack v131072 (0:14): 24.4 GB, reused (image checked)") or, from the builder window, its JSON
# events. A step is "reused" when its summary says reused or kept (its inputs were as at the last build), else "made". Plain standard library: it runs with the system's python3.
import argparse, json, os, re, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINE = re.compile(r'^\[(\d\d):(\d\d):(\d\d)\] ([✓✗⚠]) \[(\d+)/(\d+)\] (.+?) \(((?:\d+:)?\d+:\d\d)\)(?:: (.*))?$')
STAMP = re.compile(r'^\[(\d\d):(\d\d):(\d\d)\] ')
BUILDS = ('id', 'date', 'version', 'revision', 'chain', 'chip', 'ram_gb', 'macos', 'xcode', 'metal', 'wall_s', 'steps_s', 'made', 'reused', 'failed', 'warnings', 'note')
STEPS = ('id', 'part', 'step', 'state', 'seconds', 'summary')


def seconds(text):   # m:ss or h:mm:ss
    p = [int(x) for x in text.split(':')]
    return sum(v * 60 ** i for i, v in enumerate(reversed(p)))


def hms(s):
    s = int(round(s)); h, m = divmod(s // 60, 60)
    return f'{h}:{m:02d}:{s % 60:02d}' if h else f'{m}:{s % 60:02d}'


def state_of(ok, summary):
    if not ok: return 'failed'
    t = (summary or '').lower()
    return 'reused' if ('reused' in t or 'kept' in t) else 'made'


def parse(path):
    """→ {'steps': [{part, step, state, seconds, summary}], 'wall_s', 'warnings', 'game', 'revision', 'freed'}"""
    steps, part, last_k, stamps, warnings, game, revision, freed, day = [], 1, 0, [], 0, '', '', '', 0
    epoch = []
    for raw in Path(path).read_text(encoding='utf-8', errors='replace').split('\n'):
        line = raw.rstrip('\r')
        if line.startswith('{'):
            try: e = json.loads(line)
            except ValueError: continue
            if 't' in e: epoch.append(float(e['t']))
            ev = e.get('ev')
            if ev == 'bowshot_part': part += 1
            elif ev == 'stage_end':
                steps.append({'part': part, 'step': e.get('name', ''), 'state': state_of(e.get('ok', True), e.get('summary', '')), 'seconds': float(e.get('elapsed', 0)), 'summary': e.get('summary', '')})
            elif ev == 'game': game = f'{e.get("name", "")} {e.get("version", "")}'.strip()
            elif ev == 'say':
                msg = e.get('msg', '')
                if '[RED]' in msg: warnings += 1
            continue
        s = STAMP.match(line)
        if s:
            t = int(s[1]) * 3600 + int(s[2]) * 60 + int(s[3])
            if stamps and t + day * 86400 < stamps[-1] - 600: day += 1   # past midnight
            stamps.append(t + day * 86400)
        m = LINE.match(line)
        if m:
            k, n = int(m[5]), int(m[6])
            if k < last_k: part += 1   # the engine numbers its stages again for the game app
            last_k = k
            steps.append({'part': part, 'step': m[7], 'state': state_of(m[4] != '✗', m[9] or ''), 'seconds': float(seconds(m[8])), 'summary': m[9] or ''})
            if m[4] == '⚠': warnings += 0
            continue
        if '[RED]' in line: warnings += 1
        if line.startswith('Engine revision: '): revision = line.split(': ', 1)[1].strip()
        if line.startswith('FREED: ') or ('Freed ' in line and 'no longer used' not in line and not line.startswith('[')): freed = line.strip()
        g = re.search(r'game profile: (\w+)', line)
        if g: game = g[1]
    wall = (stamps[-1] - stamps[0]) if len(stamps) > 1 else (epoch[-1] - epoch[0] if len(epoch) > 1 else 0)
    return {'steps': steps, 'wall_s': wall, 'warnings': warnings, 'game': game, 'revision': revision, 'freed': freed}


def sh(*cmd):
    try: return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError): return ''


def machine():
    xc = sh('xcodebuild', '-version').split('\n')
    xcode = (xc[0].replace('Xcode ', '') + (' (' + xc[1].replace('Build version ', '') + ')' if len(xc) > 1 else '')).strip()
    return {'chip': sh('sysctl', '-n', 'machdep.cpu.brand_string') or sh('uname', '-m'), 'ram_gb': str(round(int(sh('sysctl', '-n', 'hw.memsize') or 0) / 2 ** 30)),
            'macos': sh('sw_vers', '-productVersion'), 'xcode': xcode,
            'metal': (sh('xcrun', '-sdk', 'macosx', 'metal', '--version').split('\n') or [''])[0].replace('Apple metal version ', '')}


def versions():
    def read(p):
        try: return Path(p).read_text().strip()
        except OSError: return ''
    m = re.search(r'#define DMSH_CHAIN "([0-9a-f]+)"', read(ROOT / 'dm/gfx/nvn/dmsh_chain.h'))
    return {'version': read(ROOT / 'VERSION'), 'revision': read(ROOT / 'UPSTREAM-REVISION'), 'chain': m[1] if m else ''}


def summary_row(build_id, date, parsed, note=''):
    st = parsed['steps']
    row = {'id': build_id, 'date': date, **versions(), **machine(), 'wall_s': str(round(parsed['wall_s'])), 'steps_s': str(round(sum(s['seconds'] for s in st))),
           'made': str(sum(s['state'] == 'made' for s in st)), 'reused': str(sum(s['state'] == 'reused' for s in st)), 'failed': str(sum(s['state'] == 'failed' for s in st)),
           'warnings': str(parsed['warnings']), 'note': note}
    return row


def markdown(row, parsed):
    st = parsed['steps']
    out = [f'# Build {row["id"]}', '',
           f'- Date: {row["date"]}  ·  Bowshot {row["version"]} (engine {row["revision"]}, shader chain `{row["chain"]}`)',
           f'- Machine: {row["chip"]}, {row["ram_gb"]} GB, macOS {row["macos"]}, Xcode {row["xcode"]}, Metal {row["metal"]}',
           f'- Wall clock: {hms(float(row["wall_s"]))}  ·  steps: {hms(float(row["steps_s"]))}  ·  {row["made"]} made, {row["reused"]} reused, {row["failed"]} failed  ·  {row["warnings"]} red lines']
    if parsed['freed']: out.append(f'- {parsed["freed"]}')
    if row['note']: out.append(f'- Note: {row["note"]}')
    out += ['', '| Part | Step | State | Time | Summary |', '|---|---|---|---:|---|']
    for s in st: out.append(f'| {s["part"]} | {s["step"]} | {s["state"]} | {hms(s["seconds"])} | {s["summary"].replace("|", "/")} |')
    longest = sorted(st, key=lambda s: -s['seconds'])[:3]
    if longest: out += ['', 'Longest: ' + ', '.join(f'{s["step"]} ({hms(s["seconds"])})' for s in longest)]
    return '\n'.join(out) + '\n'


def read_tsv(path, cols):
    rows = []
    try: lines = Path(path).read_text(encoding='utf-8').split('\n')
    except OSError: return rows
    for l in lines[1:]:
        if l.strip(): rows.append(dict(zip(cols, l.split('\t'))))
    return rows


def append_tsv(path, cols, rows):
    p = Path(path); p.parent.mkdir(parents=True, exist_ok=True)
    new = not p.exists()
    with open(p, 'a', encoding='utf-8') as f:
        if new: f.write('\t'.join(cols) + '\n')
        for r in rows: f.write('\t'.join(str(r.get(c, '')).replace('\t', ' ').replace('\n', ' ') for c in cols) + '\n')


def compare(a_id, b_id, folder):
    builds = {r['id']: r for r in read_tsv(Path(folder) / 'builds.tsv', BUILDS)}
    steps = read_tsv(Path(folder) / 'steps.tsv', STEPS)
    if not a_id or not b_id:
        ids = list(builds)
        if len(ids) < 2: raise SystemExit('compare needs two recorded builds (bowshot_report.py record)')
        a_id, b_id = ids[-2], ids[-1]
    for i in (a_id, b_id):
        if i not in builds: raise SystemExit(f'no recorded build {i}; recorded: {", ".join(builds)}')
    A, B = builds[a_id], builds[b_id]
    def by(i):
        out = {}
        for s in steps:
            if s['id'] == i: out[(s['part'], s['step'])] = s
        return out
    sa, sb = by(a_id), by(b_id)
    keys = list(dict.fromkeys(list(sa) + list(sb)))
    out = [f'# {a_id}  →  {b_id}', '']
    unlike = [k for k in ('chip', 'ram_gb', 'macos', 'xcode', 'metal', 'chain', 'revision') if A.get(k) != B.get(k)]
    if unlike: out += ['These two builds differ in: ' + ', '.join(f'{k} ({A.get(k)} → {B.get(k)})' for k in unlike) + '. Times are only comparable for steps these differences do not touch.', '']
    out += [f'| Step | {a_id} | {b_id} | Change |', '|---|---:|---:|---|']
    worse, state_back = [], []
    for k in keys:
        x, y = sa.get(k), sb.get(k)
        cell = lambda s: '—' if not s else f'{hms(float(s["seconds"]))} ({s["state"]})'
        change = ''
        if x and y:
            dx, dy = float(x['seconds']), float(y['seconds'])
            if x['state'] == 'reused' and y['state'] == 'made': change = 'reused → made'; state_back.append(k[1])
            elif x['state'] == 'made' and y['state'] == 'reused': change = 'made → reused'
            elif dx > 0 and dy > 1.2 * dx and dy - dx > 5: change = f'+{hms(dy - dx)} (+{round(100 * (dy - dx) / dx)}%)'; worse.append(k[1])
            elif dy < 0.8 * dx and dx - dy > 5: change = f'-{hms(dx - dy)} ({round(100 * (dy - dx) / dx)}%)'
            if x['state'] == 'failed' or y['state'] == 'failed': change = (change + ' ' if change else '') + 'FAILED'
        elif not x: change = 'new step'
        else: change = 'step gone'
        out.append(f'| {k[1]} (part {k[0]}) | {cell(x)} | {cell(y)} | {change} |')
    wa, wb = float(A['wall_s'] or 0), float(B['wall_s'] or 0)
    out += ['', f'Wall clock: {hms(wa)} → {hms(wb)}' + (f' ({"+" if wb >= wa else "-"}{hms(abs(wb - wa))})' if wa and wb else ''),
            f'Made / reused: {A["made"]}/{A["reused"]} → {B["made"]}/{B["reused"]}  ·  red lines: {A["warnings"]} → {B["warnings"]}']
    if worse: out.append('Slower: ' + ', '.join(worse))
    if state_back: out.append('Reused before, made now: ' + ', '.join(state_back))
    return '\n'.join(out) + '\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    r = sub.add_parser('report'); r.add_argument('log'); r.add_argument('--out'); r.add_argument('--id', default='')
    c = sub.add_parser('record'); c.add_argument('log'); c.add_argument('--id', required=True); c.add_argument('--note', default=''); c.add_argument('--dir', default=str(ROOT / 'docs/builds')); c.add_argument('--date', default='')
    p = sub.add_parser('compare'); p.add_argument('a', nargs='?', default=''); p.add_argument('b', nargs='?', default=''); p.add_argument('--dir', default=str(ROOT / 'docs/builds'))
    a = ap.parse_args()
    if a.cmd == 'compare': sys.stdout.write(compare(a.a, a.b, a.dir)); return 0
    parsed = parse(a.log)
    if not parsed['steps']: print('no finished step in the log', file=sys.stderr); return 1
    date = getattr(a, 'date', '') or time.strftime('%Y-%m-%d', time.localtime(Path(a.log).stat().st_mtime))
    if a.cmd == 'report':
        row = summary_row(a.id or f'{versions()["version"]} {date}', date, parsed)
        text = markdown(row, parsed)
        if a.out: Path(a.out).write_text(text, encoding='utf-8')
        else: sys.stdout.write(text)
        return 0
    folder = Path(a.dir)
    if any(r['id'] == a.id for r in read_tsv(folder / 'builds.tsv', BUILDS)): raise SystemExit(f'the build {a.id} is already recorded')
    row = summary_row(a.id, date, parsed, a.note)
    append_tsv(folder / 'builds.tsv', BUILDS, [row])
    append_tsv(folder / 'steps.tsv', STEPS, [{'id': a.id, 'part': s['part'], 'step': s['step'], 'state': s['state'], 'seconds': round(s['seconds']), 'summary': s['summary']} for s in parsed['steps']])
    (folder / 'reports').mkdir(parents=True, exist_ok=True)
    (folder / 'reports' / f'{a.id}.md').write_text(markdown(row, parsed), encoding='utf-8')
    print(f'recorded {a.id}: {row["made"]} made, {row["reused"]} reused, steps {hms(float(row["steps_s"]))}, wall {hms(float(row["wall_s"]))}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
