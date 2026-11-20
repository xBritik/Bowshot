# Changelog

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
