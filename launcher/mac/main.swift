// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

// The window and the menus; the screens are in Views.swift, what they do in Model.swift
final class BuilderDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    var window: NSWindow!
    let model = BuilderModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = (Bundle.main.object(forInfoDictionaryKey: "BowshotVersion") as? String) ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let name = version.isEmpty ? "Bowshot" : "Bowshot \(version)"   // the app's name, the window's title
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: "About \(name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(aboutItem)
        let creditsItem = NSMenuItem(title: "Credits & Licences…", action: #selector(showCredits), keyEquivalent: "")
        creditsItem.target = self
        appMenu.addItem(creditsItem)
        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(menuUpdates), keyEquivalent: "")
        updatesItem.target = self
        appMenu.addItem(updatesItem)
        let autoItem = NSMenuItem(title: "Check for Updates Automatically", action: #selector(menuAutoUpdates), keyEquivalent: "")   // once a day at most; only GitHub is asked, for the latest release
        autoItem.target = self
        appMenu.addItem(autoItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        menu.addItem(item)
        // Edit menu: without it ⌘C and ⌘A have no menu item to reach the log (a text view only copies through the responder chain's copy:)
        let editItem = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        // Game menu: every action of the screens, with its shortcut (the buttons are not the only way in)
        let gameItem = NSMenuItem(); let gameMenu = NSMenu(title: "Game")
        for (title, sel, key) in [("Choose Game Folder…", #selector(menuChoose), "o"), ("Check Tools Again", #selector(menuCheck), "r"), ("Show in Finder", #selector(menuShow), "f"), ("Open Game", #selector(menuOpen), "g")] {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key); it.target = self; gameMenu.addItem(it)
        }
        gameItem.submenu = gameMenu
        menu.addItem(gameItem)
        let windowItem = NSMenuItem(); let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = name
        window.delegate = self
        window.minSize = NSSize(width: 680, height: 540)
        window.contentView = NSHostingView(rootView: ContentView(m: model))
        if let look = ProcessInfo.processInfo.environment["BOWSHOT_APPEARANCE"] { NSApp.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }   // interface test only: check both looks without touching the Mac's setting
        window.center()
        window.setFrameAutosaveName("BowshotBuilder")   // the window comes back where it was left
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)   // the window opens calm: nothing focused
        NSApp.activate(ignoringOtherApps: true)
        model.refreshSetup()
        model.checkForUpdates()
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refreshSetup() }   // back from the App Store or Xcode: check again

    @objc func menuChoose() { if model.step == .game || model.step == .done { model.step = .game; model.chooseFolder() } }
    @objc func menuCheck() { model.refreshSetup() }
    @objc func menuShow() { model.showApp() }
    @objc func menuOpen() { model.openGame() }
    @objc func menuAutoUpdates() { UpdateCheck.automatic.toggle() }
    // "Check for Updates…": asks GitHub now and says what it found, newer or not
    @objc func menuUpdates() {
        guard let current = UpdateCheck.runningVersion else {
            let alert = NSAlert(); alert.messageText = "This copy of Bowshot does not know its version"; alert.informativeText = "Look for the latest release on the Bowshot page on GitHub."; alert.runModal(); return
        }
        UpdateCheck.check(current: current) { [weak self] outcome in
            let alert = NSAlert()
            switch outcome {
            case .newer(let release):
                alert.messageText = "Bowshot \(release.version) is available"; alert.informativeText = "You have Bowshot \(current). The release page has the download; nothing is downloaded from here."
                alert.addButton(withTitle: "View the Release"); alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(release.url) }
                self?.model.update = release
                return
            case .current: alert.messageText = "Bowshot is up to date"; alert.informativeText = "You have Bowshot \(current), the latest release."
            case .ahead(let release): alert.messageText = "This Bowshot is newer than the latest release"; alert.informativeText = "You have Bowshot \(current); the latest release is \(release.version)."
            case .failed: alert.messageText = "Could not check for updates"; alert.informativeText = "GitHub did not answer, or you are offline. Try again later."
            }
            alert.runModal()
        }
    }
    // Items that do not apply stay in the menu, dimmed
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(menuChoose): return !model.busy && (model.step == .game || model.step == .done)
        case #selector(menuCheck): return !model.busy && model.step != .build
        case #selector(menuShow), #selector(menuOpen): return model.step == .done
        case #selector(menuAutoUpdates): item.state = UpdateCheck.automatic ? .on : .off; return true
        default: return true
        }
    }
    @objc func showCredits() {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Documentation/CREDITS.md") { NSWorkspace.shared.open(url) }
    }
    /// A running build is stopped only after the player confirms; true when there is none or it was stopped
    private func confirmStopBuild() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Stop the build and close Bowshot?"
        alert.informativeText = "Closing Bowshot stops the build. The steps that are finished are kept, and your next build resumes from there."
        alert.addButton(withTitle: "Keep Building")
        alert.addButton(withTitle: "Stop Build and Close")
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        model.stopBuild()
        model.process = nil
        return true
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if model.process != nil { return confirmStopBuild() }
        if model.busy { _ = applicationShouldTerminate(NSApp); return false }
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.process != nil { return confirmStopBuild() ? .terminateNow : .terminateCancel }
        guard model.busy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A setup step is still running"
        alert.informativeText = "Keep Bowshot open until it finishes."
        alert.addButton(withTitle: "Keep Going")
        alert.runModal()
        return .terminateCancel
    }
}

if CommandLine.arguments.contains("--self-check") {
    let resources = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
    let required = ["engine/LICENSE", "engine/UPSTREAM-REVISION", "engine/scripts/bowshot_build.sh", "engine/scripts/bowshot_setup.sh", "engine/scripts/build_ipa_from_nsp.py", "Documentation/CREDITS.md"]
    let missing = required.filter { !FileManager.default.fileExists(atPath: resources.appendingPathComponent($0).path) }
    if !missing.isEmpty { fputs("Missing builder resources: \(missing.joined(separator: ", "))\n", stderr); exit(1) }
    print("Bowshot builder resources verified; no game is required for this check.")
    exit(0)
}
let application = NSApplication.shared
let delegate = BuilderDelegate()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
