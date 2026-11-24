# Build history

How long Bowshot's builds take and which steps they reuse, kept per build so two versions can be compared: did a change make a step slower, did a step that was reused start to be made again, did a build get shorter.

## What is recorded

Every build writes `Bowshot-build/build-report.md` beside its app: the steps in order with their state and time, the totals, the machine (chip, memory, macOS, Xcode, Metal) and the versions (Bowshot, engine revision, shader chain). It comes from `Bowshot-build/build.log` (`scripts/bowshot_report.py`), whether the build ran from the window or from a terminal.

A step is **reused** when the engine found its inputs as at the last build and kept its output (its summary says "reused" or "kept"), **made** when it ran, **failed** when it stopped the build. "Wall clock" is the time from the log's first line to its last; "steps" is the sum of the steps' own times, which leaves out the start (tidying, copying the engine) and what runs between steps.

## Keep a build in this folder

After a build you want to compare against later:

```bash
python3 scripts/bowshot_report.py record "/path/to/game folder/Bowshot-build/build.log" --id 0.1.2-beta-6-cold --note "first build after the shader chain changed"
```

It adds one row to `builds.tsv` (the build and its machine), the steps to `steps.tsv`, and the report to `reports/<id>.md`. An id is used once. Commit the three. Then:

```bash
python3 scripts/bowshot_report.py compare                     # the last two recorded builds
python3 scripts/bowshot_report.py compare ID_A ID_B           # any two
```

The comparison lists each step's time and state in both builds, flags a step that got more than 20 % and 5 seconds slower, a step reused before and made now (and the other way round), the wall clock, and what differs between the two (machine, Xcode, Metal, engine revision, shader chain). Times of unlike builds are only comparable for the steps those differences do not touch: say so in the note.

## Comparing like with like

A build's time depends mostly on what the last build left, so record the same three cases for each version, and compare a case with the same case:

| Case | How to get it | What to expect |
|---|---|---|
| **cold** | the first build after the shader chain changed (the Game screen says so), or after deleting `Bowshot-build/build/shader` | the shaders are compiled: hours. Most of the time is the `Mac shaders` step |
| **warm** | build again right after a build, with nothing changed | every step reused: a few minutes at most. A step made here is a regression |
| **host** | build again after a change to the host or the launcher only (`dm/host`, `dm/mac`) | the shaders and the extracted game reused; the host and the app made again |

Keep the Mac plugged in, close other apps, and do not play while it builds: the shaders' time follows the machine's load. The shader count of the `shader split` step (42,847 for this game) tells whether two builds made the same work.

## Recorded builds

`builds.tsv` is the list; the table below is for reading.

| Id | Date | Bowshot | Chain | Case | Wall clock | Note |
|---|---|---|---|---|---|---|
| 0.1.2-beta-6-cold | 2026-11-23 | 0.1.2 | `ba5a707f7ecf` | cold | 1:32:20 | 9 steps made, 5 reused (the second engine pass); shaders 36:24 with none from the cache, prebuild 19:26, archive 28:32, prewarm 2:42, app 2:32 |
| 0.1.1-cold | 2026-11-23 | 0.1.1 | `e52917b72fcf` | cold | 1:20:08 | shaders 34:00 with none from the cache, prebuild 12:01, archive 24:29, prewarm 2:15, app 2:30; the engine of 0.1.1, which plays |
| 0.1.3-warm | 2026-11-23 | 0.1.3 | `e52917b72fcf` | warm | 0:10:12 | same engine and chain as the line above: shaders restored from the cache 3:15, prebuild 0:08, archive 0:27, prewarm 1:57, app 0:49 (the host changed, so the prewarm and the app are made again) |
