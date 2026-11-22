# Changelog

## Unreleased

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

- The game's memory limit now follows the Mac's memory (2 GB less than the Mac has, between 8 and 48 GB) instead of a fixed 13 GB, which closed the game early on a Mac with more memory (a 18 GB Mac gets 16 GB). The game itself needs 13 to 16 GB, so a Mac with 16 GB is tight. The limit is written when the app is built: rebuild to get it, or set `DM_MEM_CAP_GB` in `~/Library/Application Support/nxnative/0400486024DEC000/env.txt`.
- The settings window starts on Potato (render scale 0.5) on a Mac with less than 24 GB of memory, and on Normal otherwise, because the game's memory use grows with the render scale. It is written once at build time, only when you have not chosen a scale yet, and you can change it in the window.
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
