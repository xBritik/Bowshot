# Changelog

## Unreleased

### Builder (Bowshot.app)

- The builder app is much smaller: about 60 MB in place of 880 MB. It carried 225 other games' profiles (745 MB of shader tables and notes), the project's tests and developer documentation, and files a local build left in the source tree (`dm/host/gen`, `.DS_Store`). The packaging now takes only the files Git tracks (and new files it does not ignore), and the app carries only what a build runs. The source ZIP is built the same way.
- Bowshot builds Ocarina of Time for the Mac and nothing else, and the source tree says so: the other games' profiles, the iPhone and iPad app (`dm/ios`, except `ios_metal.py`, which the shader chain reads by path and whose change would compile every shader again), the IPA and Xcode project paths of `scripts/build_ipa_from_nsp.py` (`--platform ios`, `--prepare-xcode`, `--romfs`, `--shader-files`, `--team-id`, `--xcode-workspace`), `scripts/regress.py` (it needs every game), `scripts/push_romfs.sh`, the game-request issue form and `UPSTREAM_README.md` are gone, and the tests that only covered them. The launcher's three Swift files moved from `dm/ios/Sources` to `dm/mac`.
- The first build after this update compiles every shader again (1.5 hours or more): the shader chain version changed (`174df0acb40b` to `ba5a707f7ecf`) because the comments of the chain's tools no longer name other games. The Game screen says so before you start. Nothing else about the shaders changed.
- Other games' names and title IDs are gone from the comments and docstrings of the source (`dm/gfx`, `dm/tools`, `dm/host`, `scripts`) and from the Markdown notes, replaced by "another game" (done by a script that checked the code outside the comments was byte for byte the same). Short nicknames of games (a first name alone) were not touched, nor the vendored third-party code, nor the two C# sources a prebuilt tool is locked to. The rows of per-game tables in the host (`hle_fpslock.c`, `hle_uemalloc.c`) are removed, and so is the GitHub triage tooling (`issue_areas.py`, `pr_areas.py`, `triage_report.py`) that labelled issues by game.
- Each build frees the disk space of files it will not use, and only those Bowshot made and nothing reads any more: the engine copies of other Bowshot versions (`~/Library/Application Support/Bowshot/engine/`, except one another build is running from), the `obsolete` folder of the build folder (after a successful build), and the idle Metal build folders that the pipeline archive compiler leaves in the user cache folder (`scripts/clean_metal_cache.py`: only folders nothing changed in for an hour, none while a game runs). What the next build reuses (the extracted game, the shaders, the app), your game files and other apps are never touched. The log says what was freed, and the Done screen shows the total.
- The folder the build works and writes in, inside your game folder, is now called `Bowshot-build` (it was `Bowshot-local`): it holds the finished app, the work of the build and its log. A game folder that has the old one gets it renamed at the next build, at once and keeping everything in it, so nothing is built again because of the name.
- The Game screen shows "What this build will do" before you start: whether the game files and the shaders of your last build will be reused, and when the translation chain changed (so the shaders are compiled again, 1.5 hours or more). It is read from the files of your last build and never starts the engine (`bowshot_build.sh --forecast <game folder>`, `scripts/bowshot_forecast.py`); the pipeline steps are marked as decided during the build.
- The Build and Done screens list every step with what became of it (reused, made, failed) and the time it took, and say why the shaders are compiled again when the engine reports it.
- A build writes `Bowshot-build/last-build.txt` (the Bowshot version and engine revision it was made with), which the forecast compares with the Bowshot you run.

## 0.1.2 (23 Nov 2026)

### Engine

- Upstream nxnative main `0293739d` (23 Nov 2026), pinned as `bowshot-0.1.2-nxnative-0293739d`, 225 commits after the 0.1.1 pin. Ocarina of Time: a 40 fps option on a screen at a multiple of 120 Hz (the frame step now counts in ticks of 1/120 s), the dynamic resolution's threshold scaled to the frame rate target, the screen shape (Vert+) updated in place.
- The first build after this update compiles every shader again (the shader chain changed twice upstream, and the Bowshot changes to it with it): allow the 1.5 hours or more of a first build.
- Memory: unused graphics memory is given back under pressure, idle textures are evicted, CPU-no-access texture pools stay out of the guest's window and the sparse memory reports survive a long session. The game's memory limit of 0.1.1 (the Mac's memory minus 2 GB) is unchanged.
- Fewer stutters: pipeline archives made offline are adopted before the first frame, archive writes wait while you play, background pipeline builds free their memory, the guest's clock is frozen while the archive opens, and the replay of a frame costs less CPU. Metal 4 mesh pipelines are prepared ahead.
- Audio: the sound comes back after the output device changes. The microphone's default gain is 1x (it was 4x), so humming into the ocarina is less boosted: raise Microphone gain in the settings window if the game does not hear you.
- Render scale now uses nxnative's stub for Ocarina of Time: it multiplies the size the game computes by the slider's value (1.0 is the game's own size) and keeps the game's dynamic resolution out of the way below 1.0. The slider's top is therefore the game's own 1440x810 (handheld) instead of 1920x1080: Potato (960x540, the default) keeps its size, the intermediate steps are finer, and Native is gone. The slider's marks are Potato and Game's own: there is no Normal any more.

### Builder (Bowshot.app) and game app

- The settings window no longer draws the rows the build fixes (Dynamic resolution, Console mode, Upscaling, Hold frames when late: they only showed a greyed value) nor Press a button to join (Ocarina of Time has one player). Their values still apply.
- The builder is named Bowshot <version> (Bowshot 0.1.2.app) and its window title says it.
- The game's settings window says which Bowshot built it ("Built with Bowshot 0.1.2", at the bottom left).
- The finished game app is also put in Applications (a clone on the same disk, so no extra space; `scripts/bowshot_install.sh`). The copy in Bowshot-local stays, so the next build reuses it. An app of the same name in Applications is replaced only if it is this game's, and not while it runs; if Applications cannot be written, the app stays in Bowshot-local and the log says why.
- View > Show Memory Use (⌥⌘I) shows the memory the game uses beside the limit that closes it, without changing anything.
- ⌘= and ⌘- show a message at the bottom of the picture for about 3 seconds: the Render scale (its name, percentage and size in pixels) and the memory the game uses beside the limit that closes it, read again after 1.5 seconds, once the new size's render targets exist.
- The memory warning under the Render scale slider names Potato, whose value is now 0.6667.

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
