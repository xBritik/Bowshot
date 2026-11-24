#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# What the next build will reuse and what it will make again, read from the game folder before anything runs (the builder's Game screen shows it).
# Usage: bowshot_forecast.py <game folder>      (through bowshot_build.sh --forecast <game folder>)
# One line per item: <id>|<state>|<title>|<what to tell the player>     state: new (no earlier build), reuse, redo, check (decided while the build runs)
# It only looks at what the earlier build left (file names and the files bowshot_build.sh records); it never starts the engine and never writes. The engine
# still decides each step by its own keys when it runs, so this is a forecast: a step marked reuse can still be made again when an input it keys on
# (Xcode, Metal, the game's own shader inputs) changed, and the line says so. Plain standard library: it runs with the system's python3.
import os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = re.compile(r'b-([0-9a-f]{12})(\.img)?')   # a finished shader library: the folder b-<chain> or the one file b-<chain>.img (not .part, not .key)


def line(i, state, title, text): print('|'.join((i, state, title, text.replace('|', '/').replace('\n', ' '))))


def read(p):
    try: return Path(p).read_text(encoding='utf-8', errors='replace')
    except OSError: return ''


def current_chain():   # the translation chain this Bowshot builds with (dm/gfx/nvn/dmsh_chain.h), None when the file is not there
    m = re.search(r'#define DMSH_CHAIN "([0-9a-f]+)"', read(ROOT / 'dm/gfx/nvn/dmsh_chain.h'))
    return m.group(1) if m else None


def cached_chains(cache):   # the chains of the finished Mac shader libraries the last build left
    out = set()
    try: names = os.listdir(cache)
    except OSError: return out
    for n in names:
        m = LIB.fullmatch(n)
        if m: out.add(m.group(1))
    return out


def recorded(private):   # bowshot_build.sh's note of the last successful build: key=value lines
    d = {}
    for l in read(private / 'last-build.txt').splitlines():
        k, _, v = l.partition('=')
        if k and v: d[k.strip()] = v.strip()
    return d


def main(argv):
    if len(argv) != 2: print('Usage: bowshot_forecast.py <game folder>', file=sys.stderr); return 2
    game = Path(argv[1])
    private = game / 'Bowshot-build'
    if not private.exists() and (game / 'Bowshot-local').is_dir(): private = game / 'Bowshot-local'   # before 0.1.3 its name; the build renames it
    work = private / 'build'
    if not work.is_dir():
        line('first', 'new', 'First build', 'Nothing was built here yet, so every step is made: 1.5 hours or more.')
        return 0
    version, rev = read(ROOT / 'VERSION').strip(), read(ROOT / 'UPSTREAM-REVISION').strip()
    last = recorded(private)
    if last.get('version') and last.get('revision'):
        if (last['version'], last['revision']) != (version, rev): line('last', 'check', 'New Bowshot since your last build', f'Last built with Bowshot {last["version"]} ({last["revision"]}), now {version} ({rev}).')
    # The game's files: kept while they are as the extraction recorded them (the engine compares each package's name, size and time at the start)
    if any(work.glob('extract/*/RomFS.img')) or any(work.glob('extract/*/extract.key')):
        line('extract', 'reuse', 'Game files', 'Already extracted. Checked again at the start: a game file that changed is extracted again.')
    else:
        line('extract', 'new', 'Game files', 'Not extracted yet: the first steps unpack your game file (tens of GB).')
    # The shaders: the biggest cost. The libraries on disk are named after the translation chain that made them, the engine reuses them only for the same chain
    chain, have = current_chain(), cached_chains(work / 'shader' / 'cache')
    if chain is None: line('shaders', 'check', 'Shaders', 'Decided while the build runs.')
    elif chain in have: line('shaders', 'reuse', 'Shaders', 'Same translation chain as the libraries on disk: reused, unless Xcode, Metal or the game\'s shader inputs changed (the build says so).')
    elif have: line('shaders', 'redo', 'Shaders', f'The translation chain changed ({", ".join(sorted(have))} to {chain}): every shader is compiled again, 1.5 hours or more.')
    else: line('shaders', 'new', 'Shaders', 'No finished shader library on disk: they are compiled, 1.5 hours or more.')
    # What the engine only knows when it runs
    line('pipelines', 'check', 'Pipeline archive and prewarm', 'Decided while the build runs: seconds when their inputs are unchanged, minutes to hours when they changed.')
    if (private / 'Ocarina of Time.app').is_dir(): line('app', 'redo', 'Game app', 'Made again from the steps above; the parts that did not change are cloned, not copied.')
    else: line('app', 'new', 'Game app', 'Packed at the end.')
    return 0


if __name__ == '__main__': sys.exit(main(sys.argv))
