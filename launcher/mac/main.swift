// SPDX-License-Identifier: MIT
import AppKit
import Foundation

final class BuilderDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let folder = NSTextField(string: "")
    let log = NSTextView()
    let status = NSTextField(labelWithString: "Choose a folder containing your own game dump.")
    let build = NSButton(title: "Build My Local Game", target: nil, action: nil)
    let choose = NSButton(title: "Choose Game Folder…", target: nil, action: nil)
    let reveal = NSButton(title: "Open game folder", target: nil, action: nil)
    let bar = NSProgressIndicator()                      // the current step's progress (indeterminate while it cannot be counted)
    let stepLabel = NSTextField(labelWithString: "")      // "Step 3/9: Mac shaders · translating — 28 % — about 11 min left"
    let logToggle = NSButton(title: "Show build log", target: nil, action: nil)
    var logScroll: NSScrollView!
    var stage = (k: 0, n: 0, name: "", step: "")         // the step shown: the engine's stage in the first part, "Game app" in the second (BOWSHOT_PROGRESS=json)
    var firstStages = 0                                   // how many stages the engine planned for the first part: the second part is step firstStages + 1
    var appPart = false                                   // the second part has begun (bowshot_build.sh's bowshot_part event)
    var inner = (k: 0, n: 0, name: "")                    // the engine's own stage within the second part
    var appStart = Date()
    var stepStart = Date()                                // when the step shown began: its elapsed time is on the step line, ticking every second
    var detail = ""                                       // the step line's count part: " — 28 % — about 11 min left"
    var ticker: Timer?
    // Setup: the tools the build needs, checked and installed from here (scripts/bowshot_setup.sh)
    let setupBox = NSStackView()
    var setupRows: [String: (text: NSTextField, button: NSButton)] = [:]
    var setupStates: [String: (state: String, detail: String)] = [:]
    var setupProcess: Process?
    var setupReady = false
    var lastBeat = Date()                                 // the last line the log got: a step that says nothing for a minute gets a "still running" line
    var process: Process?
    var output: URL?
    var pending = ""                 // the end of the output that has no newline yet: a line is coloured once it is whole
    var sawError = false             // an ERROR: line was shown
    var lastWarning: NSRange?        // the last [RED] line of the engine: when the build fails, it is the reason, shown in red

    enum Tone { case normal, error, ready }
    // The status line under the buttons: red for a blocking error, green when the game app is ready
    func setStatus(_ text: String, _ tone: Tone = .normal) {
        status.stringValue = text
        status.textColor = tone == .error ? .systemRed : tone == .ready ? .systemGreen : .labelColor
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let creditsItem = NSMenuItem(title: "Credits & Licences…", action: #selector(showCredits), keyEquivalent: "")
        creditsItem.target = self
        appMenu.addItem(creditsItem)
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
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Bowshot — Local Game Builder"
        window.delegate = self
        window.minSize = NSSize(width: 720, height: 640)
        let title = NSTextField(labelWithString: "Bowshot")
        title.font = .boldSystemFont(ofSize: 25)
        let iconView = NSImageView(image: NSApp.applicationIconImage)   // Bowshot's bow and arrow (the bundle's AppIcon.icns)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let heading = NSStackView(views: [iconView, title]); heading.orientation = .horizontal; heading.alignment = .centerY; heading.spacing = 12
        let subtitle = NSTextField(wrappingLabelWithString: "A Mac builder powered by nxnative. No game, console keys, saves or game shaders are included. Your game is built locally and must stay private.")
        folder.placeholderString = "Your game folder stays outside the source repository"
        folder.isEditable = false
        choose.target = self; choose.action = #selector(chooseFolder)
        build.target = self; build.action = #selector(startBuild)
        reveal.target = self; reveal.action = #selector(showOutput); reveal.isEnabled = false
        build.keyEquivalent = "\r"   // the window's default button: drawn in the accent blue while it is enabled
        build.isEnabled = false        // until a valid game folder is chosen (folderProblem)
        let row = NSStackView(views: [folder, choose]); row.orientation = .horizontal
        folder.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [build, reveal]); buttons.orientation = .horizontal
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        log.isEditable = false; log.isSelectable = true; log.usesFindBar = true
        log.frame = NSRect(x: 0, y: 0, width: 780, height: 240)
        log.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        log.autoresizingMask = [.width]; log.isVerticallyResizable = true
        log.textContainer?.widthTracksTextView = true
        scroll.documentView = log
        bar.style = .bar; bar.isIndeterminate = false; bar.minValue = 0; bar.maxValue = 1; bar.isHidden = true
        stepLabel.isHidden = true; stepLabel.lineBreakMode = .byTruncatingTail
        logToggle.bezelStyle = .inline; logToggle.target = self; logToggle.action = #selector(toggleLog)
        scroll.isHidden = true   // the whole log, folded by default (Show build log)
        logScroll = scroll
        let setupTitle = NSTextField(labelWithString: "Set up your Mac (once)"); setupTitle.font = .boldSystemFont(ofSize: 14)
        let again = NSButton(title: "Check Again", target: self, action: #selector(recheckSetup)); again.bezelStyle = .inline
        setupBox.orientation = .vertical; setupBox.alignment = .leading; setupBox.spacing = 8
        setupBox.setViews([NSStackView(views: [setupTitle, again]),
                           makeSetupRow("xcode", "Xcode", #selector(setupXcode)),
                           makeSetupRow("metal", "Metal Toolchain", #selector(setupMetal)),
                           makeSetupRow("tools", "Build tools", #selector(setupTools))], in: .top)
        setupBox.isHidden = true   // until the first check says something is missing
        setupBox.setHuggingPriority(.required, for: .vertical)   // the box keeps its own height: the window's spare height goes elsewhere
        for v in setupBox.arrangedSubviews { v.setContentHuggingPriority(.required, for: .vertical) }
        let credits = NSTextField(wrappingLabelWithString: "Engine: seedds / nxnative · Ocarina fork: cheemu21 / kid-with-sword-remake · Full contributors and licences are included under Documentation.")
        credits.font = .systemFont(ofSize: 11)
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13
        let spacer = NSView(); spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .vertical)   // takes the window's spare height, so no row of the setup box stretches
        stack.setViews([heading, subtitle, setupBox, row, buttons, status, stepLabel, bar, logToggle, scroll, spacer], in: .top)
        stack.setViews([credits], in: .bottom)   // the credits stay at the window's foot, the log folded or not
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stepLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            credits.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setStatus("Checking your Mac…")
        refreshSetup()
    }

    func applicationDidBecomeActive(_ notification: Notification) { refreshSetup() }   // back from the App Store or Xcode: check again

    // MARK: Setup
    func makeSetupRow(_ id: String, _ title: String, _ action: Selector) -> NSStackView {
        let text = NSTextField(labelWithString: title); text.lineBreakMode = .byTruncatingTail
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let button = NSButton(title: "Install", target: self, action: action); button.bezelStyle = .rounded; button.controlSize = .small; button.isHidden = true
        setupRows[id] = (text, button)
        let row = NSStackView(views: [text, button]); row.orientation = .horizontal; row.spacing = 12
        return row
    }
    func setupScript() -> URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("engine/scripts/bowshot_setup.sh"), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    @objc func recheckSetup() { refreshSetup() }
    func refreshSetup() {
        guard setupProcess == nil, process == nil, let script = setupScript() else { return }
        DispatchQueue.global().async { [weak self] in
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/bash"); task.arguments = [script.path, "--status"]
            let pipe = Pipe(); task.standardOutput = pipe; task.standardError = FileHandle.nullDevice; task.standardInput = FileHandle.nullDevice
            guard (try? task.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
            let out = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { self?.applySetup(out) }
        }
    }
    func applySetup(_ output: String) {
        setupStates = [:]
        for line in output.components(separatedBy: "\n") {
            let p = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            if p.count == 3 { setupStates[p[0]] = (p[1], p[2]) }
        }
        func ok(_ id: String) -> Bool { setupStates[id]?.state == "ok" }
        let xcodeOK = ok("xcode")
        func show(_ id: String, _ good: Bool, _ text: String, button: String? = nil, enabled: Bool = true) {
            guard let row = setupRows[id] else { return }
            row.text.stringValue = (good ? "✓ " : "• ") + text
            row.text.textColor = good ? .systemGreen : .labelColor
            row.button.isHidden = good || button == nil
            if let b = button { row.button.title = b }
            row.button.isEnabled = enabled && setupProcess == nil
        }
        let x = setupStates["xcode"]
        show("xcode", xcodeOK, x?.detail ?? "Xcode", button: x?.state == "manual" ? "Open App Store" : x?.state == "select" ? "Select Xcode…" : x?.state == "firstlaunch" ? "Open Xcode" : nil)
        show("metal", ok("metal"), setupStates["metal"]?.detail ?? "Metal Toolchain", button: "Install", enabled: xcodeOK)
        let missing = [("uv", "uv"), ("zstd", "zstd"), ("glslang", "glslang")].filter { !ok($0.0) }.map { $0.1 }
        show("tools", missing.isEmpty, missing.isEmpty ? "Build tools (uv, zstd, glslang)" : "Build tools to install: \(missing.joined(separator: ", "))", button: "Install", enabled: xcodeOK)
        setupReady = !setupStates.isEmpty && xcodeOK && ok("metal") && missing.isEmpty
        setupBox.isHidden = setupReady
        updateBuildButton()
    }
    @objc func setupXcode() {
        switch setupStates["xcode"]?.state ?? "" {
        case "manual": if let url = URL(string: "https://apps.apple.com/app/xcode/id497799835") { NSWorkspace.shared.open(url) }
        case "firstlaunch":
            let apps = ((try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []).filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }.sorted()
            if let app = apps.last { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/" + app)) }
        case "select": runSetup(["--select-xcode"], title: "Selecting Xcode…")
        default: break
        }
    }
    @objc func setupMetal() { runSetup(["--install", "metal"], title: "Downloading the Metal Toolchain (a few GB)…") }
    @objc func setupTools() { runSetup(["--install", "tools"], title: "Installing the build tools…") }

    // One setup step: the script's output goes to the build log (opened), and the setup is checked again when it ends
    func runSetup(_ args: [String], title: String) {
        guard setupProcess == nil, process == nil, let script = setupScript() else { return }
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/bash"); task.arguments = [script.path] + args
        let pipe = Pipe(); task.standardOutput = pipe; task.standardError = pipe; task.standardInput = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r", with: "\n")   // curl's progress bar redraws with \r
            DispatchQueue.main.async { self?.append(text) }
        }
        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setupProcess = nil; self.append("", flush: true); self.bar.stopAnimation(nil); self.bar.isHidden = true; self.stepLabel.isHidden = true
                if finished.terminationStatus != 0 { self.setStatus("That setup step failed. The log below says why.", .error) }
                self.refreshSetup()
                self.updateBuildButton()
                if finished.terminationStatus != 0 { self.setStatus("That setup step failed. The log below says why.", .error) }
            }
        }
        if logScroll.isHidden { toggleLog() }
        appendLine("— \(title)")
        do {
            try task.run(); setupProcess = task
            setStatus(title); build.isEnabled = false
            for r in setupRows.values { r.button.isEnabled = false }
            bar.isHidden = false; bar.isIndeterminate = true; bar.startAnimation(nil)
        } catch { setStatus("Could not start the setup: \(error.localizedDescription)", .error) }
    }

    @objc func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "Choose your own dump folder, outside any Git repository."
        if panel.runModal() == .OK, let url = panel.url { folder.stringValue = url.path; updateBuildButton() }
    }

    // Why the chosen folder cannot be built, nil when it can: the checks bowshot_build.sh makes first (it exists, it is outside any Git repository and outside the
    // builder), and that it holds a game: a .nup, NSP / XCI files (.nsp .nsz .xci .xcz) or a dump (base/). The script still checks the game and its update itself
    func folderProblem(_ path: String) -> String? {
        let fm = FileManager.default; var isDir: ObjCBool = false
        guard !path.isEmpty else { return "Choose a folder containing your own game dump." }
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return "That folder no longer exists. Choose your game folder again." }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        var dir = url
        while true {
            if fm.fileExists(atPath: dir.appendingPathComponent(".git").path) { return "Choose a game folder outside a Git repository. Private game outputs must stay separate from source." }
            let up = dir.deletingLastPathComponent(); if up.path == dir.path { break }; dir = up
        }
        if let res = Bundle.main.resourceURL?.resolvingSymlinksInPath().path, url.path == res || url.path.hasPrefix(res + "/") { return "Keep game files outside the builder." }
        let names = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        let game = names.contains { n in
            let e = (n as NSString).pathExtension.lowercased()
            return !n.hasPrefix("._") && ["nup", "nsp", "nsz", "xci", "xcz"].contains(e)
        }
        var baseDir: ObjCBool = false
        if !game && !(fm.fileExists(atPath: url.appendingPathComponent("base").path, isDirectory: &baseDir) && baseDir.boolValue) {
            return "No game found in that folder: it needs your game's .nup file, its NSP files (base game and update v131072), or a dump folder."
        }
        return nil
    }

    // The Build button is enabled (and blue) only for a valid folder and while no build runs
    func updateBuildButton() {
        let problem = folderProblem(folder.stringValue)
        let busy = process != nil || setupProcess != nil
        build.isEnabled = !busy && setupReady && problem == nil
        if !busy {
            if !setupReady { setStatus(setupStates.isEmpty ? "Checking your Mac…" : "First, finish the setup steps above.") }
            else if let problem = problem { setStatus(problem, .error) } else { setStatus("Ready to build. The first full build can take 1.5+ hours.") }
        }
    }

    // The log, line by line: bowshot_build.sh's blocking errors (ERROR: ) in red, the engine's warnings ([RED] ) in orange, the finished app (READY: and the line
    // after it) in green, everything else in the text colour
    func append(_ text: String, flush: Bool = false) {
        pending += text
        var lines = pending.components(separatedBy: "\n")
        let tail = lines.removeLast()
        for line in lines { appendLine(line) }
        if flush { if !tail.isEmpty { appendLine(tail) }; pending = "" } else { pending = tail }
        log.scrollToEndOfDocument(nil)
    }
    var readyNext = false
    @objc func toggleLog() {
        logScroll.isHidden.toggle()
        logToggle.title = logScroll.isHidden ? "Show build log" : "Hide build log"
        if !logScroll.isHidden { log.scrollToEndOfDocument(nil) }
    }

    // About how long is left, from the engine's estimate in seconds
    func left(_ eta: Double) -> String {
        if eta < 60 { return "less than a minute left" }
        let m = Int((eta / 60).rounded())
        return m < 60 ? "about \(m) min left" : "about \(m / 60) h \(String(format: "%02d", m % 60)) min left"
    }

    // The engine's progress (build_ipa_from_nsp.py --progress json): stage, step, progress and stage_end move the bar and the step line; say is a message for the log
    func handleEvent(_ e: [String: Any]) {
        let ev = e["ev"] as? String ?? ""
        switch ev {
        case "bowshot_part":   // the second part: one step of its own, after the first part's stages
            appPart = true; appStart = Date(); newStep()
            stage = (firstStages + 1, firstStages + 1, e["name"] as? String ?? "Game app", "preparing")
            inner = (0, 0, "")
            bar.isIndeterminate = true; bar.startAnimation(nil); bar.isHidden = false; stepLabel.isHidden = false
            refreshLabel()
            appendLine("[\(stage.k)/\(stage.n)] \(stage.name) …")
        case "stage":
            let k = e["k"] as? Int ?? 0, n = e["n"] as? Int ?? 0, name = e["name"] as? String ?? "", step = e["step"] as? String ?? ""
            newStep()
            if appPart {
                inner = (k, n, name); stage.step = step.isEmpty ? name : "\(name) · \(step)"
                if n > 0 { bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = Double(k - 1) / Double(n) }
                refreshLabel()
                appendLine("[\(stage.k)/\(stage.n)] \(stage.name) · \(stage.step) …")
            } else {
                firstStages = n
                stage = (k, n + 1, name, step)   // + 1: the second part, still to come
                bar.isIndeterminate = true; bar.startAnimation(nil); bar.isHidden = false; stepLabel.isHidden = false
                refreshLabel()
                appendLine("[\(stage.k)/\(stage.n)] \(stage.name)" + (stage.step.isEmpty ? "" : " · \(stage.step)") + " …")
            }
        case "step":
            let step = e["step"] as? String ?? ""
            newStep()
            stage.step = appPart ? (step.isEmpty ? inner.name : "\(inner.name) · \(step)") : step
            refreshLabel()
            appendLine("[\(stage.k)/\(stage.n)] \(stage.name) · \(stage.step) …")
        case "progress":
            var text = ""
            if appPart {   // the second part's bar: its engine stages done, plus the current one's share
                if inner.n > 0 {
                    let f = (Double(inner.k - 1) + (e["frac"] as? Double ?? 0)) / Double(inner.n)
                    bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = f
                    text += " — \(Int((f * 100).rounded())) %"
                }
            } else {
                if let f = e["frac"] as? Double {
                    bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = f
                    text += " — \(Int((f * 100).rounded())) %"
                } else if !bar.isIndeterminate { bar.isIndeterminate = true; bar.startAnimation(nil) }
            }
            if let d = e["done"] as? Double, let t = e["total"] as? Double, t > 0, (e["unit"] as? String ?? "") != "" {   // the count: "4,887/8,345 lines"
                let nf = NumberFormatter(); nf.numberStyle = .decimal
                text += " — \(nf.string(from: NSNumber(value: Int(d))) ?? "")/\(nf.string(from: NSNumber(value: Int(t))) ?? "") \(e["unit"] as? String ?? "")"
            }
            if let note = e["note"] as? String, !note.isEmpty { text += " — " + note }
            if let eta = e["eta"] as? Double { text += " — " + left(eta) }
            detail = text
            refreshLabel()
        case "stage_end":
            let ok = e["ok"] as? Bool ?? true, warn = e["warn"] as? Bool ?? false
            let sec = Int(e["elapsed"] as? Double ?? 0), summary = e["summary"] as? String ?? ""
            let mark = warn ? "⚠" : ok ? "✓" : "✗", time = "\(sec / 60):\(String(format: "%02d", sec % 60))"
            if appPart {
                if inner.n > 0 { bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = Double(inner.k) / Double(inner.n) }
                appendLine("\(mark) [\(stage.k)/\(stage.n)] \(stage.name) · \(inner.name) (\(time))" + (summary.isEmpty ? "" : ": \(summary)"))
            } else {
                bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = 1
                appendLine("\(mark) [\(stage.k)/\(stage.n)] \(stage.name) (\(time))" + (summary.isEmpty ? "" : ": \(summary)"))
            }
        case "say":
            for l in (e["msg"] as? String ?? "").components(separatedBy: "\n") { appendLine(l) }
        case "game":
            appendLine("Game: \(e["name"] as? String ?? "?") \(e["version"] as? String ?? "")")
        default: break
        }
    }
    // The step line: the step, its count and time left from the engine, and how long the step has run (the engine says nothing for minutes in some steps)
    func refreshLabel() {
        guard stage.k > 0 else { return }
        stepLabel.stringValue = stepTitle() + detail + " — " + clock(Date().timeIntervalSince(stepStart)) + " elapsed"
    }
    func newStep() { stepStart = Date(); lastBeat = stepStart; detail = "" }
    func clock(_ seconds: Double) -> String {
        let t = Int(seconds), h = t / 3600, m = t % 3600 / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
    // Every second while a build runs: the elapsed time moves, and a step that has logged nothing for a minute says it is still running
    func tick() {
        guard process != nil, stage.k > 0 else { return }
        refreshLabel()
        if Date().timeIntervalSince(lastBeat) >= 60 {
            appendLine("  … \(stage.name) still running, \(clock(Date().timeIntervalSince(stepStart))) in this step" + detail)
        }
    }
    func playDone() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("BuildDone.mp3")
        let sound = url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? NSSound(contentsOf: $0, byReference: true) : nil } ?? NSSound(named: "Glass")
        sound?.play()
    }
    func stepTitle() -> String { "Step \(stage.k)/\(stage.n): \(stage.name)" + (stage.step.isEmpty ? "" : " · \(stage.step)") }

    func appendLine(_ line: String) {
        if line.hasPrefix("{"), let data = line.data(using: .utf8), let e = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], e["ev"] != nil { handleEvent(e); return }
        let color: NSColor
        if line.hasPrefix("ERROR: ") { color = .systemRed; sawError = true }
        else if line.hasPrefix("READY: ") || readyNext { color = .systemGreen }
        else if line.hasPrefix("[RED] ") { color = .systemOrange }
        else { color = .textColor }
        readyNext = line.hasPrefix("READY: ")
        lastBeat = Date()
        guard let storage = log.textStorage else { return }
        let start = storage.length
        storage.append(NSAttributedString(string: line + "\n", attributes: [.foregroundColor: color, .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]))
        if line.hasPrefix("[RED] ") { lastWarning = NSRange(location: start, length: (line as NSString).length) }
    }

    @objc func startBuild() {
        guard process == nil, setupProcess == nil, setupReady else { return }
        if let problem = folderProblem(folder.stringValue) { setStatus(problem, .error); build.isEnabled = false; return }
        guard let resources = Bundle.main.resourceURL else { setStatus("The app resources are missing.", .error); return }
        let script = resources.appendingPathComponent("engine/scripts/bowshot_build.sh")
        guard FileManager.default.fileExists(atPath: script.path) else { setStatus("Builder files are missing; use a complete release archive.", .error); return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path, "--build", folder.stringValue]
        var env = ProcessInfo.processInfo.environment; env["BOWSHOT_PROGRESS"] = "json"; task.environment = env   // the engine's progress as events for the bar
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        task.standardInput = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { self?.append(text) }
        }
        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil; self.choose.isEnabled = true
                self.ticker?.invalidate(); self.ticker = nil
                self.build.isEnabled = self.setupReady && self.folderProblem(self.folder.stringValue) == nil
                self.append("", flush: true)
                self.bar.stopAnimation(nil)
                if finished.terminationStatus == 0 {
                    self.setStatus("Local build ready. Keep the resulting game app private.", .ready)
                    self.playDone()
                    self.bar.isIndeterminate = false; self.bar.doubleValue = 1; self.stepLabel.stringValue = "Done"
                    if self.appPart {
                        let sec = Int(Date().timeIntervalSince(self.appStart))
                        self.appendLine("✓ [\(self.stage.k)/\(self.stage.n)] \(self.stage.name) (\(sec / 60):\(String(format: "%02d", sec % 60)))")
                    }
                } else {
                    self.bar.isHidden = true
                    self.stepLabel.stringValue = self.stage.k > 0 ? "Stopped at " + self.stepTitle().replacingOccurrences(of: "Step", with: "step") : "Stopped before the first step"
                    if self.logScroll.isHidden { self.toggleLog() }   // the reason is in the log: open it
                    self.setStatus("Build stopped. The red line in the log explains what to fix.", .error)
                    if let r = self.lastWarning, let storage = self.log.textStorage, NSMaxRange(r) <= storage.length { storage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: r) }   // the engine's reason
                    else if !self.sawError { self.appendLine("ERROR: The build stopped (exit \(finished.terminationStatus)) without a message. The full log is build.log in Bowshot-local.") }
                }
                self.reveal.isEnabled = self.output.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            }
        }
        output = URL(fileURLWithPath: folder.stringValue).appendingPathComponent("Bowshot-local")
        log.string = ""; pending = ""; lastWarning = nil; sawError = false; readyNext = false; stage = (0, 0, "", ""); firstStages = 0; appPart = false; inner = (0, 0, ""); detail = ""; stepLabel.stringValue = "Starting…"; stepLabel.isHidden = false; bar.isHidden = false; bar.isIndeterminate = true; bar.startAnimation(nil); setStatus("Building from your files. The first full build can take 1.5+ hours.")
        build.isEnabled = false; choose.isEnabled = false; reveal.isEnabled = false
        do {
            try task.run(); process = task
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        } catch {
            build.isEnabled = setupReady && folderProblem(folder.stringValue) == nil; choose.isEnabled = true
            setStatus("Could not start the builder: \(error.localizedDescription)", .error)
        }
    }

    @objc func showOutput() { if let url = output { NSWorkspace.shared.open(url) } }
    @objc func showCredits() {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Documentation/CREDITS.md") { NSWorkspace.shared.open(url) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if process != nil { _ = applicationShouldTerminate(NSApp); return false }
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard process != nil else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A local build is still running"
        alert.informativeText = "Keep Bowshot open until it finishes. Closing the window does not cancel the engine's compiler jobs."
        alert.addButton(withTitle: "Keep Building")
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
