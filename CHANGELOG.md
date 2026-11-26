# Changelog

## 0.2.0 (24 Nov 2026)

Xbox and PlayStation controller layouts, and amiibo.

- **Controller layout.** A new Controller layout setting (`DM_PAD_LAYOUT`: Nintendo Switch, Xbox, PlayStation). An Xbox or PlayStation pad then uses its own face-button labels (the bottom button is A), and the button icons in the game match it. `DM_PAD_MAP` remaps single buttons, for example `A=B,B=A`. On the Mac, Automatic picks the layout from the connected controller (PlayStation, Xbox or Switch) when the game starts; the first controller found decides for the whole session.
- **Amiibo.** The game finds a virtual amiibo: the new Amiibo menu in the menu bar lists the figures Ocarina of Time accepts (Young Link and Young Zelda masks, the Zelda series), and the one picked is found at the next scan, so it changes while you play. No amiibo file or key is used. Made from the host work of kid-with-sword-remake (MIT); turn on System, Options, Use amiibo in the game once, then scan as usual. Checked in play on the Mac (the game finds the figure). The daily limit on the drops is lifted by default (`DM_AMIIBO_LIMIT=1` keeps it): the build makes a RomFS overlay from your own copy of the game, so Bowshot carries no Nintendo files.
- **Ocarina of Time on a PlayStation or Xbox pad.** The controller screens, the callout banners and the ocarina and key prompts are redrawn for the pad. The builder makes them from your own copy of the game, so Bowshot carries no Nintendo files. Made on the Mac, not yet checked in play.

## 0.1.4 (24 Nov 2026)

A fix for the Mac setup screen. Nothing in the engine or the game changes.

- **Build tools install again.** On a Mac without Homebrew, the setup screen's Install button for the build tools failed on glslang ("Could not install glslangValidator") and the build could not start. Khronos ships `glslangValidator` as a link to `glslang`, and the installer unpacked the link without its target. It now installs the real binary under that name. A Mac that already has `glslangValidator` was never affected.
- **zstd installs too.** It follows glslang in the same step, so it was never reached after that failure.
- **A broken tool is replaced.** The setup screen used to count a tool as installed when its file existed, even if it did not start (a Homebrew install that lost a library, for example). It now runs each tool, and Bowshot installs its own copy of one that does not start. The build checks the same way.
- **A failed install says so.** The Build tools line now says the last try failed and points to the log. Before, it looked unchanged.

## 0.1.3 (24 Nov 2026)

0.1.2 was never released: its engine makes the game's GPU hang after a few minutes ([seedds/nxnative#3274](https://github.com/seedds/nxnative/issues/3274)). 0.1.3 keeps 0.1.1's engine and takes only what does not touch it. A game built with 0.1.1 is reused.

- **Forecast.** The Game screen says what the next build keeps or makes again, with a time estimate.
- **Build report.** Every step shows its time and whether it was reused. Each build writes `Bowshot-build/build-report.md`.
- **Shorter first build.** A pipeline cache that only the terminal run command reads is skipped. It saves 12 to 19 minutes and 7 to 9 GB of disk.
- **Stop a build safely.** Closing the window asks first, then stops the build and its compiler jobs. Finished steps are kept.
- **Dynamic resolution** works at 100 % render scale. It sits under Render scale and is greyed out below 100 %. Read from the code, not yet measured in play.
- **Settings window.** Shortcuts are drawn as keys, Advanced settings opens from its whole line, and rows the build fixes are hidden.
- **In the game.** ⌘= and ⌘- show the render scale and the memory in use. The microphone's default gain is 1x (it was 4x).
- **Update check.** The builder and the game's settings window ask GitHub once a day at most. Nothing about you is sent. Turn it off with `DM_UPDATE_CHECK=0` or the Bowshot menu.
- **Game app in Applications** too, as a clone with no extra space. `Bowshot-local` is now `Bowshot-build`.
- **Less disk.** Each build frees old engine copies, the `obsolete` folder and idle Metal build folders. The builder is 60 MB instead of 880 MB.
- **First-start fix.** The engine waits up to 5 minutes for a new native tool to start (it waited 1).
- **Mac only, one game.** Other games and the iPhone app are gone from the source tree.
- **Held back with 0.1.2:** its engine update (40 fps option, memory and stutter fixes, audio recovery). It returns once the GPU hang is understood.

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
