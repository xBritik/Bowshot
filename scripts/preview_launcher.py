#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Shows Ocarina of Time's settings window as the game app packs it, without the game and without a build: a small preview app made from this tree
# (dm/mac/Launcher.swift with the shared rows, dm/ios/Sources/Launcher*.swift, and the launcher.json dm/games/settings.py writes for the Mac), with the rows
# bowshot_build.sh's runtime.env fixes shown fixed, as in the packed app. Play and Quit close it. Its choices are kept apart from the game's (its own bundle ID).
# Needs Xcode (clang, swiftc). Usage: python3 scripts/preview_launcher.py [<output folder>]   (default: /tmp/bowshot-launcher-preview)
import json, os, plistlib, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = '0400486024DEC000'
NAME = 'The Legend of Zelda: Ocarina of Time'

MAIN = '''import Foundation
// The preview's entry: the settings an env file fixes (bowshot_build.sh's runtime.env), as launcher.c sets them before the window, then the window itself
@main struct LauncherPreview {
    static func main() {
        let fixed: [(String, String)] = [%s]
        for (k, v) in fixed { setenv(k, v, 1) }
        setenv("DM_ENV_FILE_KEYS", fixed.map { $0.0 }.joined(separator: " "), 1); setenv("DM_ENV_LAUNCH_KEYS", "", 1)
        setenv("DM_SAVE", NSTemporaryDirectory() + "bowshot-launcher-preview-save", 1)
        let r = dmMacLauncher()
        print(r == 1 ? "launcher preview: Play (nothing more to start)" : r == 0 ? "launcher preview: Quit" : "launcher preview: no window")
    }
}
'''


def run(cmd, **kw):
    print('+', ' '.join(str(c) for c in cmd), flush=True)
    subprocess.run([str(c) for c in cmd], check=True, **kw)


def xcrun(tool):
    return subprocess.run(['xcrun', '--find', tool], check=True, capture_output=True, text=True).stdout.strip()


def runtime_env():   # the KEY=VALUE lines bowshot_build.sh writes into runtime.env for this game
    text = (ROOT / 'scripts/bowshot_build.sh').read_text(encoding='utf-8')
    block = re.search(r"<<'SETTINGS'\n(.*?)\nSETTINGS\n", text, re.S)
    return [tuple(l.split('=', 1)) for l in block[1].splitlines() if '=' in l] if block else []


def launcher_json(out):   # settings.py for the Mac, as the packer runs it: a render-scale stub (the rewriter's RENDER_SCALE) and the microphone offered
    sys.path[:0] = [str(ROOT / 'dm/games'), str(ROOT / 'dm/tools')]
    os.environ.update(SETTINGS_PLATFORM='mac', GFXAPI='nvn')
    import settings, nso_syms
    nso_syms.audio_input_capable = lambda paths: True   # the game's modules are not here; Ocarina of Time's main has audio input
    with tempfile.TemporaryDirectory() as t:
        (Path(t) / 'main.fixups.tsv').write_text('# RENDER_SCALE\t1\n# DYNAMIC_RESOLUTION\t1\n')   # Ocarina of Time v131072's frame step stub
        d = settings.build(GAME, t, Path(t) / 'control.nacp')
    out.write_text(json.dumps(d, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    return d['settings']


def main():
    if sys.platform != 'darwin': sys.exit('preview_launcher.py runs on a Mac with Xcode')
    base = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/bowshot-launcher-preview').resolve()
    app = base / f'{NAME}.app'; contents = app / 'Contents'
    (contents / 'MacOS').mkdir(parents=True, exist_ok=True); (contents / 'Resources/dm').mkdir(parents=True, exist_ok=True)
    listed = launcher_json(contents / 'Resources/dm/launcher.json')
    rules = [{'env': s['env'], **({'min': float(s['min']), 'max': float(s['max'])} if s['kind'] == 'range' else
                                  {'values': [o[0] for o in s['options']]} if s['kind'] == 'choice' else {'values': [s.get('on', '1'), s.get('off', '0')]})} for s in listed]
    icon = ROOT / 'launcher/mac/AppIcon.png'
    iconset = base / 'AppIcon.iconset'; iconset.mkdir(exist_ok=True)
    for n in (16, 32, 128, 256, 512):
        for k, suffix in ((1, ''), (2, '@2x')):
            run(['sips', '-z', n * k, n * k, icon, '--out', iconset / f'icon_{n}x{n}{suffix}.png'], stdout=subprocess.DEVNULL)
    run(['iconutil', '-c', 'icns', iconset, '-o', contents / 'Resources/AppIcon.icns'])
    (contents / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleName': NAME, 'CFBundleDisplayName': NAME, 'CFBundleIdentifier': 'local.bowshot.launcher-preview', 'CFBundleExecutable': 'launcher',
        'CFBundleShortVersionString': 'preview', 'CFBundleVersion': '1', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'AppIcon',
        'LSMinimumSystemVersion': '26.6', 'NSHighResolutionCapable': True, 'DMTitleID': GAME, 'DMSettings': rules}))
    sdk = subprocess.run(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], check=True, capture_output=True, text=True).stdout.strip()
    fixed = runtime_env()
    (base / 'preview_main.swift').write_text(MAIN % ', '.join(f'("{k}", "{v}")' for k, v in fixed), encoding='utf-8')
    run([xcrun('clang'), '-isysroot', sdk, '-arch', 'arm64', '-mmacosx-version-min=26.6', '-O2', '-I', ROOT / 'dm/host', '-c', '-o', base / 'save_sync.o', ROOT / 'dm/host/save_sync.c'])
    run([xcrun('swiftc'), '-sdk', sdk, '-target', 'arm64-apple-macos26.6', '-swift-version', '5', '-parse-as-library', '-module-cache-path', base / 'module-cache',
         '-o', contents / 'MacOS/launcher', ROOT / 'dm/mac/Launcher.swift', ROOT / 'dm/ios/Sources/LauncherSettings.swift', ROOT / 'dm/ios/Sources/LauncherRow.swift',
         ROOT / 'dm/ios/Sources/SaveSyncReport.swift', base / 'preview_main.swift', base / 'save_sync.o',
         '-framework', 'CoreFoundation', '-framework', 'AppKit', '-framework', 'SwiftUI', '-framework', 'AVFAudio', '-framework', 'CoreAudio'])
    print(f'\nPreview app: {app}\nFixed as in the game app (runtime.env): {", ".join(k for k, _ in fixed)}\n', flush=True)
    run([contents / 'MacOS/launcher'])


if __name__ == '__main__':
    main()
