# Credits and provenance

## Direct lineage

- **seedds**, creator/maintainer of [nxnative](https://github.com/seedds/nxnative). The original MIT notice remains in `LICENSE`.
- **cheemu21**, maintainer of [kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake), the direct source of this snapshot.
- Pinned revision: `e9c2f7e1f19a8c74e90283e892b8973173eabd61`.
- Shader chain used by that snapshot: `dc815e0f38ca`.
- Native-execution foundation: [jhaizhou-ops/d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile), as acknowledged upstream.

## People

[AUTHORS.md](AUTHORS.md) lists every recorded author and co-author trailer credit in the imported history, with commit counts and a representative commit. It preserves recorded names rather than guessing real identities from usernames. In particular, **Xipzer** and **Pedro Nascimento** have imported performance and graphics work; **nanotchec** and the other contributors are retained in that list. The imported fork documentation also credits the authors of the merged upstream PRs; those acknowledgements are retained in `docs/games/kid-with-sword-remake.md`.

## Libraries and reference projects

The full upstream notes are in [dm/third_party/README.md](dm/third_party/README.md). Ryujinx, LibHac, SPIRV-Cross, glslang, Atmosphère, MacNativeGames, dav1d, libvpx, stb_vorbis, Vulkan-Headers, FLIP and their contributors retain their respective credits and licences. Existing third-party licence files are preserved in the source and in the builder’s bundled engine.

## GreenKid-MV

Bowshot is a fork of [GreenKid-MV](https://github.com/adi0900/GreenKid-MV) by **Motion_Viz** (0.3.0, engine `ab41d6a1`). The local builder UI, public-content checks, release packaging, the Normal / Potato resolution presets and game-file overlays, the GPU-hang watchdog and the dispatch and texel-fetch clamps are GreenKid-MV's work; its copyright line is kept in `LICENSE`. They do not make the upstream shader or runtime fixes original GreenKid-MV work.

## Bowshot additions

The Render scale choice and its live steps, the in-game Performance HUD toggle (Apple's Metal HUD), the bow-and-arrow icon, and the move to nxnative main `8c94bd1e` with kid-with-sword-remake's render-target pacing and Texture Memory Saver. They do not make the upstream or GreenKid-MV work original Bowshot work.

## README reference

[tangerineturtle1/NX2navi](https://github.com/tangerineturtle1/NX2navi) was a reference for a concise README with status, features, installation, limitations and licence information. No code or game assets were taken from it, and no claim is made to its separately restricted additions.

## Publication snapshot

Upstream gameplay images and upstream automation workflows were excluded from this snapshot. Source profiles contain compatibility metadata and build rules, not a playable game. Three tiny synthetic parser fixtures are retained by exact hash; they are manufactured headers, not commercial executable modules. This source snapshot carries no Git history and does not include personal logs or runtime settings.
