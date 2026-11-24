# Changelog

## 0.1.3 (unreleased)

0.1.2 was never released: its engine update (nxnative `0293739d`) makes Ocarina of Time's GPU hang after one to four minutes (`kIOGPUCommandBufferCallbackErrorHang`; reported upstream as [seedds/nxnative#3274](https://github.com/seedds/nxnative/issues/3274)). 0.1.3 keeps 0.1.1's engine, which plays, and takes from 0.1.2 and from the work done after it only what does not touch the engine. **The shader chain is 0.1.1's (`e52917b72fcf`): a game built with 0.1.1 is reused, and nothing about the shaders, the pipeline archive or the extracted game is made again.**

### From 0.1.2 (kept)

- The finished game app is also put in Applications (a clone on the same disk, so no extra space; `scripts/bowshot_install.sh`). The copy in `Bowshot-build` stays, so the next build reuses it. An app of the same name in Applications is replaced only if it is this game's, and not while it runs; if Applications cannot be written, the app stays in `Bowshot-build` and the log says why.
- The builder is named Bowshot <version> and its window title says it; the game's settings window says which Bowshot built it ("Built with Bowshot 0.1.3", at the bottom left).
- The settings window no longer draws the rows the build fixes (Dynamic resolution, Console mode, Upscaling, Hold frames when late), nor Press a button to join (Ocarina of Time has one player), nor the Show this window at launch checkbox. Their values still apply.
- ⌘= and ⌘- show a message at the bottom of the picture for about 3 seconds: the Render scale (its name, percentage and size in pixels) and the memory the game uses beside the limit that closes it, read again after 1.5 seconds. View > Show Memory Use (⌥⌘I) shows the memory alone. It is a native label over the window, drawn only when one of these keys is pressed.
- The microphone's default gain is 1x (it was 4x), so humming into the ocarina is less boosted: raise Microphone gain in the settings window if the game does not hear you.

### Builder (Bowshot.app)

- The Game screen shows "What this build will do" before you start: whether the game files and the shaders of your last build will be reused, and when the translation chain changed (so the shaders are compiled again, 1.5 hours or more). It is read from the files of your last build and never starts the engine (`bowshot_build.sh --forecast <game folder>`, `scripts/bowshot_forecast.py`).
- The Build and Done screens list every step with what became of it (reused, made, failed) and the time it took, and say why the shaders are compiled again when the engine reports it.
- Every build writes `Bowshot-build/build-report.md`: its steps in order, which were reused and which made, the time of each, the machine and the versions. `scripts/bowshot_report.py record` keeps a build in `docs/builds/` and `compare` sets two builds side by side (slower steps, steps reused before and made now); `docs/builds/README.md` says how to compare like with like.
- `scripts/bowshot_watch.py <game folder>` serves a page on 127.0.0.1 that follows a build while it runs (step, bar, time left, steps done, disk, log). It only reads.
- The folder the build works and writes in, inside your game folder, is now called `Bowshot-build` (it was `Bowshot-local`). A game folder that has the old one gets it renamed at the next build, at once and keeping everything in it, so nothing is built again because of the name. A build writes `Bowshot-build/last-build.txt` (the Bowshot version and engine revision it was made with), which the forecast compares with the Bowshot you run.
- Each build frees the disk space of files it will not use, and only those Bowshot made and nothing reads any more: the engine copies of other Bowshot versions (`~/Library/Application Support/Bowshot/engine/`, except one another build is running from), the `obsolete` folder of the build folder (after a successful build), and the idle Metal build folders that the pipeline archive compiler leaves in the user cache folder (`scripts/clean_metal_cache.py`: only folders nothing changed in for an hour, none while a game runs). What the next build reuses (the extracted game, the shaders, the app), your game files and other apps are never touched. The log says what was freed, and the Done screen shows the total.

### Repository: Mac only and Ocarina of Time only

The source tree and the builder app carried the upstream project's other games and its iPhone and iPad app. Bowshot builds one game on the Mac, so they are gone, and the builder app goes from 880 MB to about 60 MB.

- **Other games' profiles:** the 225 profiles in `dm/games` are deleted (745 MB). `dm/games` keeps Ocarina of Time (`0400486024DEC000`), the shared readers and `settings.tsv`. `dm/games/README.md` lost its table of games and its "Adding a game" chapter.
- **iPhone and iPad:** `dm/ios` is deleted except `dm/ios/tools/ios_metal.py`, which the shader chain reads by path (changing the chain's files compiles every shader again). The launcher's three Swift files moved to `dm/mac`.
- **Scripts and tooling:** `scripts/regress.py` (it needs every game), `scripts/push_romfs.sh`, the GitHub game-request form, the issue and pull-request labelling tools and `UPSTREAM_README.md` are deleted.
- **Notes:** other games' names and title IDs in the Markdown notes are replaced by "another game" and `<title ID>`; links in the docs to the deleted profiles are dead.
- **Packaging** takes only the files Git tracks, where it took everything in the folder (local build output included: `dm/host/gen`, 43 MB, and `.DS_Store` files). The app leaves out tests, fuzz corpora and developer documentation: a build reads none of them.
- **Not touched on purpose, to leave the engine and its shader chain as in 0.1.1:** the code and comments of `dm/gfx`, `dm/host`, `dm/tools` and `dm/third_party` (other games' names stay in them), the iOS branches inside the shader tools and in `scripts/build_ipa_from_nsp.py`, and the readers for other games' formats. They go with a version that builds the shaders again anyway.

### Held back with 0.1.2 (not in this version)

The engine update to nxnative `0293739d`: the 40 fps option, the dynamic resolution's threshold following the frame rate target, memory given back under pressure and idle texture eviction, the stutter fixes (pipeline archives adopted before the first frame), the audio recovery after an output change, nxnative's render-scale stub (Potato and Game's own marks, Native gone), the MacBook 16:10 picture shape, and the Pipeline prebuild and archive progress and the two-groups-at-a-time archive build made on top of that engine. They come back one by one, or with the engine, once the GPU hang is understood.

## 0.1.1 (20 Nov 2026)

### Builder (Bowshot.app)

- A new guided interface in four screens: Your Mac (setup), Game (choose or drop your game folder, with the folder checked at once), Build (one progress bar for the whole build, the current step, the time left and the time elapsed) and Done (open the game, show it in Finder). A failed build says why and offers Try Again.
- Setup screen: Bowshot checks Xcode, the Metal Toolchain and the build tools when it opens, and installs what it can with one button each (no Terminal, no Homebrew). `uv`, `glslangValidator` and `zstd` go into `~/Library/Application Support/Bowshot/tools`, with pinned versions and SHA-256 checks. Xcode itself is still installed from the App Store; Build stays off until every step is green.
- xcodegen is no longer required: it is only for iOS builds.
- The step line shows how long the current step has run, ticking every second, and a step that logs nothing for a minute adds a "still running" line to the build log.
- Prewarm pipelines shows its count (`4,887/8,345 lines`), the bases compiled and the time left, read from the host's own progress lines.
- The build log can be selected and copied with ⌘C (there is an Edit menu with Copy and Select All).
- A sound plays when a build finishes.
- Bowshot's icon is shown in the builder window.

### Engine

- A Mac with less than 16 GB of memory cannot build the game: the setup screen shows a Memory line that is not ready, and the build refuses with a clear message.
- The game's memory limit now follows the Mac's memory (2 GB less than the Mac has, between 8 and 48 GB) instead of a fixed 13 GB, which closed the game early on a Mac with more memory (a 18 GB Mac gets 16 GB, a 16 GB Mac 15 GB). The game itself needs 13 to 16 GB, so a Mac with 16 GB is tight. The limit is written when the app is built: rebuild to get it, or set `DM_MEM_CAP_GB` in `~/Library/Application Support/nxnative/0400486024DEC000/env.txt`.
- The render scale now starts on Potato (0.5) for every Mac, because the game already needs 13 to 16 GB of memory at that scale and more as it rises. Normal and Native stay a click away.
- The game's settings window shows a warning right under the Render scale slider when the render scale is above Potato on a Mac with less than 24 GB of memory (the game's memory use grows with the scale and it can close itself).
- Performance record: the game log gets a `perf:` line every 10 seconds (average frame rate, the frame rate of the slowest 1 % of frames, the worst frame, frames over 25 ms, dropped frames, GPU average and 95th percentile). It is the data behind performance reports. `DM_PERF_LOG=<seconds>` changes the interval, `0` turns it off.

## 0.1.0 (21 Nov 2026)

The first Bowshot release: a Mac builder for Zelda: Ocarina of Time (Switch 2, update v131072) on nxnative, built from your own dump. No game material is included.

### Engine

- Upstream nxnative main `8c94bd1e` (21 Nov 2026), pinned as `bowshot-0.1.0-nxnative-8c94bd1e`: Ocarina of Time's lighting, terrain and stability fixes, its foliage no longer crashing Apple's mesh compiler on macOS 26.6 (#3069), a corrected v131072 shader map (#3010), shader library files unmapped once loaded, a real-time audio thread, a startup display fix (#3004).
- MetalFX draws Ocarina of Time's own upscaler networks, the default here (`upscaler_default metalfx`); Game's own keeps Nintendo's network.
- Render targets drawn over are released a few at a time (kid-with-sword-remake L6.3), and Texture Memory Saver, off by default, drops large textures' sharpest level (kid-with-sword-remake L7).
- Safeguards: the GPU-hang watchdog, and the clamps of GPU-written dispatch counts and of texel fetches past a texture's edge.

### Game app (Ocarina of Time.app)

- Render scale slider in the settings window: 50 % to 100 % of 1920×1080 in twelfths, Normal (1280×720) by default, Potato and Native marked under it.
- In game: ⌘= / ⌘- step the Render scale, ⌥⌘P shows or hides the Performance HUD (Apple's Metal HUD); the settings window lists them under While you play.
- Frame rate, Display mode and Game's upscaler can be changed in the settings window (defaults: 60 fps, a window, MetalFX); Console mode stays Handheld. Each menu names its default.
- The app is named Ocarina of Time.app; its icon is the game's own, else Bowshot's bow.

### Builder (Bowshot.app)

- New name and icon (an original bow and arrow).
- Build My Local Game turns blue once the folder is valid, with the reason shown when it is not.
- A progress bar with the current step, its percentage and the time left; the game app is a step of its own.
- The full build log is folded under Show build log: blocking errors in red, warnings in orange, the finished app in green.
- scripts/preview_launcher.py shows the game's settings window without a game or a build.
