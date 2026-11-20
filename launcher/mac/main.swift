// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

// The window and the menus; the screens are in Views.swift, what they do in Model.swift
final class BuilderDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let model = BuilderModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let creditsItem = NSMenuItem(title: "Credits & Licences…", action: #selector(showCredits), keyEquivalent: "")
        creditsItem.target = self
        appMenu.addItem(creditsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Bowshot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Bowshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        menu.addItem(item)
        // Edit menu: without it ⌘C and ⌘A have no menu item to reach the log (a text view only copies through the responder chain's copy:)
        let editItem = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        let windowItem = NSMenuItem(); let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Bowshot"
        window.delegate = self
        window.minSize = NSSize(width: 680, height: 540)
        window.contentView = NSHostingView(rootView: ContentView(m: model))
        window.center(); window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)   // the window opens calm: nothing focused
        NSApp.activate(ignoringOtherApps: true)
        model.refreshSetup()
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refreshSetup() }   // back from the App Store or Xcode: check again

    @objc func showCredits() {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Documentation/CREDITS.md") { NSWorkspace.shared.open(url) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if model.busy { _ = applicationShouldTerminate(NSApp); return false }
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = model.process != nil ? "A local build is still running" : "A setup step is still running"
        alert.informativeText = model.process != nil ? "Keep Bowshot open until it finishes. Closing the window does not cancel the engine's compiler jobs." : "Keep Bowshot open until it finishes."
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
