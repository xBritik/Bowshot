<p align="center"><img src="launcher/mac/AppIcon.png" alt="Bowshot icon: a bow and arrow" width="160"></p>

<h1 align="center">Bowshot</h1>

<p align="center"><strong>The Legend of Zelda: Ocarina of Time (Switch 2) as a native Mac app,<br>built on your Mac from your own game file, on <a href="https://github.com/seedds/nxnative">nxnative</a></strong></p>

<p align="center">
  <a href="https://github.com/xBritik/Bowshot/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/xBritik/Bowshot?label=latest%20release"></a>
  <img alt="macOS 26.6+ on Apple silicon" src="https://img.shields.io/badge/macOS-26.6%2B%20Apple%20silicon-black?logo=apple">
  <img alt="graphics: Metal and MetalFX" src="https://img.shields.io/badge/graphics-Metal%20%2B%20MetalFX-blue">
  <img alt="license: MIT" src="https://img.shields.io/badge/license-MIT-yellow">
</p>

<p align="center">
  <a href="https://ko-fi.com/G8M72B0DPM"><img alt="Buy me a coffee on Ko-fi" src="https://img.shields.io/static/v1?label=BUY%20A%20COFFEE&amp;message=KO-FI&amp;color=F16B66&amp;labelColor=555555&amp;logo=ko-fi&amp;logoColor=white&amp;style=for-the-badge"></a>
</p>

<p align="center">
  <a href="https://github.com/xBritik/Bowshot/releases">Releases</a> &middot;
  <a href="#features">Features</a> &middot;
  <a href="#what-you-need">Requirements</a> &middot;
  <a href="#install">Install</a> &middot;
  <a href="#play">Play</a> &middot;
  <a href="#if-something-goes-wrong">Troubleshooting</a> &middot;
  <a href="#for-developers">Developers</a> &middot;
  <a href="#credits">Credits</a>
</p>

---

Bowshot is a Mac app that builds the game **on your Mac, from your own game file**. It is based on [nxnative](https://github.com/seedds/nxnative) and the Ocarina of Time work from [kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake). **No game files are included.** You can only play the copy you build yourself.

> **Experimental preview.** Tested only with Ocarina of Time **update v131072**, on Apple silicon Macs.
>
> 0.1.2 was **never released**. Its engine makes the game's GPU hang after a few minutes ([seedds/nxnative#3274](https://github.com/seedds/nxnative/issues/3274)). 0.1.3 keeps 0.1.1's engine, which plays. See the [changelog](CHANGELOG.md).

**[Download the latest Bowshot](https://github.com/xBritik/Bowshot/releases/latest)** (currently 0.2.0)

## Features

| Feature | What it does |
|---|---|
| 🧭 **Simplified install** | Four screens guide you: Your Mac, Game, Build, Done |
| ⚡ **Fast rebuilds** | The first build takes 1 hour or more; a rebuild took about 10 minutes on an M3 Pro, and the Game screen says what is kept |
| 🔎 **In-game resolution change** | **⌘=** and **⌘-** change the Render scale from 50 % to 100 % while you play |
| 📐 **Dynamic resolution** | Works at 100 % Render scale |
| ✨ **MetalFX upscaling** | Apple's MetalFX upscaler sharpens edges and text when the game renders below the screen's resolution |
| 🎮 **Controller layout** | Nintendo Switch, Xbox or PlayStation face buttons, with matching button icons in the game |
| 📊 **Performance HUD** | **⌥⌘P** shows or hides it; **⌥⌘I** shows the memory the game uses |
| 🔄 **Update check** | The builder and the game's settings window ask GitHub once a day at most; nothing about you is sent |
| 💾 **Light on disk** | Each build frees what it will not use; the builder is about 60 MB |

## What's new in 0.2.0

- **Controller layout.** A new setting picks Nintendo Switch, Xbox or PlayStation face buttons. On the Mac, Automatic reads the connected controller when the game starts. The button icons in the game match the pad.
- **Ocarina of Time on a PlayStation or Xbox pad.** The controller screens, the callout banners and the ocarina and key prompts are redrawn for the pad. The builder makes them from your own copy of the game. Made on the Mac, not yet checked in play.
- **Amiibo.** An **Amiibo** menu in the menu bar lists the figures Ocarina of Time accepts. Pick one, then scan it in the game as usual; it changes while you play. The daily limit on the drops is lifted: the build makes that from your own copy of the game. Not yet checked in play.

Earlier highlights, from 0.1.4:

- **Build tools install again** on a Mac without Homebrew. The setup screen's Install button failed on glslang and the build could not start.
- **A broken tool is replaced.** The setup screen now runs each tool instead of trusting that its file exists, and installs its own copy of one that does not start.
- **A failed install says so** on the Build tools line, with a pointer to the log.

Earlier highlights, from 0.1.3:

- **Forecast** before a build, with a time estimate.
- **Dynamic resolution** works at 100 % render scale. It was read from the code, not yet measured in play.
- **Safer builder.** Closing it during a build asks first.
- **Game app in Applications** too, with no extra space.
- **Update check** in the builder and in the game's settings window.
- **Smaller builder.** 60 MB instead of 880 MB.
- **In the game.** ⌘= and ⌘- show the render scale and the memory in use. The microphone's default gain is now 1x.
- **Tidier source tree.** Only Ocarina of Time, no iPhone app.

Everything from [0.1.1](CHANGELOG.md#011-20-nov-2026) and [0.1.0](CHANGELOG.md#010-21-nov-2026) is still there. **[Read the full changelog →](CHANGELOG.md)**

## Contents

- [Features](#features)
- [What's new in 0.2.0](#whats-new-in-020)
- [What you need](#what-you-need)
- [Install](#install)
- [Play](#play)
- [If something goes wrong](#if-something-goes-wrong)
- [Disk space](#disk-space)
- [Keep it private](#keep-it-private)
- [For developers](#for-developers)
- [Credits](#credits)
- [Licence and project identity](#licence-and-project-identity)

## What you need

- A Mac with an **Apple chip** (M1 or newer) and **16 GB of memory or more**.
- **macOS 26.6 or later.**
- **About 100 GB of free disk space.**
- **Your own copy of Ocarina of Time (Switch 2), update v131072.** One `.nup` file, or the `.nsp` files (game and update). Bowshot does not provide it.
- A Mac **plugged in**, and an internet connection. Allow a few hours.

## Install

1. **Download.** On the [latest release page](https://github.com/xBritik/Bowshot/releases/latest), get **`Bowshot-<version>-macOS-arm64.zip`**. Not the files named *Source code*.
2. **Install.** Open the zip. Drag **Bowshot** into **Applications**.
3. **Open it.** Apple has not signed the app, so your Mac blocks it once. Open **Bowshot**, close the pop-up, then go to **System Settings → Privacy & Security**. Click **Open Anyway** next to Bowshot.
4. **Follow the screens.**
   - **Your Mac.** Bowshot checks Xcode 27.2, the Metal Toolchain and the build tools. Click the button next to each missing item. Xcode comes from the App Store.
   - **Game.** Put your game file in a folder of its own, outside Desktop, Documents and iCloud Drive. Choose that folder, then click **Build My Local Game**.
   - **Build.** Wait. Keep the Mac plugged in and awake.
   - **Done.** Click **Open Game**.

## Play

1. Open **Ocarina of Time** (in Applications, or in the **Bowshot-build** folder inside your game folder). The first time, your Mac blocks it as it did Bowshot: go to **System Settings → Privacy & Security** and click **Open Anyway**.
2. Allow access to a folder if your Mac asks. Saves need it.
3. Click **Play** in the settings window.
4. Use the **keyboard** or a **controller**.
5. Press **⌘Q** to quit. **Save in the game first.**

| Keys | What it does |
|---|---|
| **⌘ =** | Sharper picture (heavier) |
| **⌘ −** | Lighter picture (smoother) |
| **⌥ ⌘ P** | Show or hide the Performance HUD |
| **⌥ ⌘ I** | Show the memory the game uses |

**For smooth play:** play in a window, keep it visible, close other apps, stay plugged in. Short stutters in a new area are normal. If it stutters, lower the **Render scale**.

## If something goes wrong

| Problem | What to do |
|---|---|
| "The app cannot be opened" | Open **System Settings → Privacy & Security** and click **Open Anyway** next to the app. |
| **Build My Local Game** stays grey | Read the line under the folder. Wrong folder, missing game file, or a folder in iCloud or a Git project. |
| A red line about a missing tool, **Xcode 27.2** or the **Metal Toolchain** | Go back to **Your Mac** and use the buttons there. |
| `The supported Ocarina of Time v131072 RomFS image was not found` | Your folder lacks **update v131072**. This version needs it. |
| The build stops | The red line says why. The full log is `Bowshot-build/build.log` in your game folder. Click **Try Again**: it resumes. |
| Black game window | Keep the window visible, not in full screen. Quit with ⌘Q and reopen. |

Still stuck? [Open an issue](https://github.com/xBritik/Bowshot/issues) with your Mac model, macOS version and the error. **Never attach game files, saves or keys.**

## Disk space

Each build frees what Bowshot made and nothing reads any more: old engine copies, the `obsolete` folder in `Bowshot-build`, and idle Metal build folders in your user cache. It never deletes your game files or what the next build reuses. To get that space back too, delete `Bowshot-build/build`. The next build then starts from zero.

## Keep it private

**Never share, upload or publish** `Ocarina of Time.app`, the `Bowshot-build` folder, your game file or your saves. They hold game material. Bowshot itself holds none.

---

# For developers

Everything below is for people who want to understand, build or contribute to Bowshot.

### Where things are

| What | Where |
|---|---|
| Your game app (private) | `/Applications/Ocarina of Time.app`, and the same app in `<game folder>/Bowshot-build/` (a clone on the same disk: no extra space; the next build reuses it) |
| Build log | `<game folder>/Bowshot-build/build.log` |
| Version of the last build (the Game screen's forecast reads it) | `<game folder>/Bowshot-build/last-build.txt` |
| What the build did and how long each step took | `<game folder>/Bowshot-build/build-report.md` |
| Settings chosen for your build | `<game folder>/Bowshot-build/runtime.env` |
| Game settings file (overrides) | `~/Library/Application Support/nxnative/0400486024DEC000/env.txt` |
| Game log (attach to bug reports; its `perf:` lines give the frame rate every 10 seconds) | `~/Library/Logs/nxnative/0400486024DEC000.log` |
| Builder's engine copy and Python | `~/Library/Application Support/Bowshot/` |

### Building Bowshot from source

This makes the **game-free builder**, not a game. The Python tools need Python 3.14, which `uv` installs. Install the build tools first (the builder's first screen does it), then:

```sh
git clone https://github.com/xBritik/Bowshot.git
cd Bowshot
uv run --no-project --python 3.14 tools/check_content.py
uv run --no-project --python 3.14 -m unittest discover -s tests -v
uv run --no-project --python 3.14 tools/package_builder.py
```

`dist/<version>/` then holds `Bowshot <version>.app`, the builder ZIP, a source ZIP, `SHA256SUMS.txt` and `CONTENT-CHECK.json` (one folder a version, so earlier builds stay); `dist/` is ignored by Git. Publish only the builder ZIP as a release asset, not the app bundle; GitHub adds the source archives itself. To make it again, delete `dist/` first. `python3 tools/package_builder.py --beta N` makes a local test build, `Bowshot <VERSION>-beta-N.app`: the name, the window title and the "Built with Bowshot" line of the games it builds say the beta, and the `VERSION` file does not change.

To see the game's settings window without a game or a build (about a minute):

```sh
uv run --no-project --python 3.14 scripts/preview_launcher.py
```

For a local game build without the builder window:

```sh
bash scripts/bowshot_build.sh --doctor
bash scripts/bowshot_build.sh --build /path/to/your/game-folder
```

### What belongs on GitHub

| Shareable project material | Keep private and outside the repository |
|---|---|
| This source snapshot and its original licence notices | NUP, NSP, NSZ, XCI, XCZ and extracted game modules |
| Bowshot's game-free builder ZIP | Any locally generated game app (`Ocarina of Time.app`) or game IPA |
| Source ZIP, content-check report and SHA-256 checksums | RomFS images, game models, textures, audio and overlays |
| Build instructions and upstream acknowledgements | Translated game shader libraries, pipeline caches, saves and console keys |

Run `python3 tools/check_content.py --staged` before staging changes. Ignore rules do not remove files already committed. This snapshot starts without upstream Git history; its origin and revision are in `UPSTREAM-REVISION`, [CREDITS.md](CREDITS.md) and [AUTHORS.md](AUTHORS.md).

### Known limitations

- This is a builder, not a prebuilt copy of Zelda. Each player builds from their own files.
- Performance and visual issues can come from the underlying engine. There is no guarantee of 60 FPS or glitch-free lighting.
- A fresh machine needs Xcode and the build tools of the first screen. The .NET SDK is not needed.
- The first local build is lengthy. Don't run a compiler-heavy build while judging gameplay performance.
- The game's memory limit is your Mac's memory minus 2 GB (minus 1 GB on a 16 GB Mac), between 8 and 48 GB. The game itself needs 13 to 16 GB while it runs, with short peaks when an area loads, so on a 16 GB Mac it can still close itself. Bowshot refuses to build on a Mac with less than 16 GB.
- Upstream gameplay screenshots are omitted from this snapshot; some historical documentation still refers to that gallery.
- Apple silicon Macs only.

## Credits

The original developers deserve the credit for the runtime, graphics and game support:

| People / project | Contribution |
|---|---|
| [seedds / nxnative](https://github.com/seedds/nxnative) | Base project, host/runtime, Metal integration, rewriter and continuing fixes. Original MIT copyright retained. |
| [Motion_Viz / GreenKid-MV](https://github.com/adi0900/GreenKid-MV) | The project Bowshot is forked from: the local-builder launcher, content checks and packaging, the Normal / Potato resolution presets and game-file overlays, the GPU-hang watchdog and the dispatch and texel-fetch clamps. |
| [cheemu21 / kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake) | The fork GreenKid-MV 0.1.0 was built on: Ocarina-specific integration, presets, upscaling work and documented Mac/iPhone experiments. |
| Xipzer | Performance work credited in the imported history and fork documentation. |
| Pedro Nascimento | Imported graphics-scale work and other contributions, as recorded in the upstream history. |
| [All recorded upstream contributors](AUTHORS.md) | The complete author list from the pinned source snapshot, with example commit links. |
| [jhaizhou-ops / d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile) | The native-execution foundation acknowledged by nxnative. |
| Ryujinx, LibHac, SPIRV-Cross, Atmosphère, MacNativeGames and the other dependency authors | Translation, extraction, system references and supporting libraries. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). |

Bowshot, like GreenKid-MV before it, adds the distribution boundary, local-builder launcher and packaging checks. It does not claim authorship of the imported engine fixes. The straightforward README organization was inspired by [NX2navi](https://github.com/tangerineturtle1/NX2navi); none of that project's code, artwork or restricted additions were imported.

## Licence and project identity

The imported engine retains its [MIT licence](LICENSE). Third-party components retain their own terms and notices.

No software licence grants rights to Nintendo's game content. Removing game data from a release is a technical distribution boundary, not legal clearance. Bowshot is an independent project and is not affiliated with or endorsed by Nintendo. Game and platform names belong to their respective owners.
