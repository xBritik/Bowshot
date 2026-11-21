// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

// The four screens of the builder, in order: the tools it needs, the game folder, the build, the finished app
enum Step: Int, CaseIterable {
    case setup, game, build, done
    var title: String { ["Your Mac", "Game", "Build", "Done"][rawValue] }
}

// What the setup screen lists: Xcode, the Metal Toolchain, and the three small build tools together
enum Requirement: String, CaseIterable { case xcode, metal, tools }

struct RequirementRow {
    var ok: Bool
    var title: String
    var detail: String
    var button: String?
    var enabled: Bool
}

final class BuilderModel: ObservableObject {
    // MARK: Screens
    @Published var step: Step = .setup

    // MARK: Setup (scripts/bowshot_setup.sh)
    @Published var checked = false                       // the first check of the Mac has answered
    @Published var setupStates: [String: [String]] = [:]  // id -> [state, detail]
    @Published var setupBusy: String?                    // the title of the setup step that runs, nil when none
    var setupProcess: Process?

    // MARK: Game folder
    @Published var folder = ""

    // MARK: Build
    @Published var building = false
    @Published var failed = false
    @Published var failure = ""
    @Published var stageTitle = "Starting…"              // "Mac shaders"
    @Published var stageIndex = ""                       // "Step 3 of 8"
    @Published var stageDetail = ""                      // "1,203/19,592 shaders · about 11 min left"
    @Published var fraction: Double = 0                  // the whole build, 0 to 1
    @Published var elapsed: TimeInterval = 0
    @Published var finishedIn: TimeInterval = 0
    let log = NSTextStorage()                            // shared by the log views of the setup and build screens

    var process: Process?
    var output: URL?
    var ticker: Timer?
    var buildStart = Date()
    var stepStart = Date()
    var lastBeat = Date()
    var pending = ""                                     // the end of the output that has no newline yet
    var sawError = false
    var lastWarning: NSRange?
    var readyNext = false
    var stage = (k: 0, n: 0, name: "", step: "")
    var firstStages = 0
    var appPart = false
    var inner = (k: 0, n: 0, name: "")
    var curFrac = 0.0
    var countText = ""

    init() {
        if let f = ProcessInfo.processInfo.environment["BOWSHOT_TEST_FOLDER"] { folder = f }   // interface test: a folder chosen at launch
    }

    var busy: Bool { process != nil || setupProcess != nil }

    // MARK: - Setup

    func setupScript() -> URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("engine/scripts/bowshot_setup.sh"), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func state(_ id: String) -> String { setupStates[id]?.first ?? "" }
    func detail(_ id: String) -> String { setupStates[id].flatMap { $0.count > 1 ? $0[1] : nil } ?? "" }
    var xcodeOK: Bool { state("xcode") == "ok" }
    var toolsMissing: [String] { ["uv", "zstd", "glslang"].filter { state($0) != "ok" } }
    var setupReady: Bool { !setupStates.isEmpty && xcodeOK && state("metal") == "ok" && toolsMissing.isEmpty }

    func row(_ r: Requirement) -> RequirementRow {
        switch r {
        case .xcode:
            let s = state("xcode")
            let button = s == "manual" ? "Open App Store" : s == "select" ? "Select Xcode…" : s == "firstlaunch" ? "Open Xcode" : nil
            return RequirementRow(ok: xcodeOK, title: "Xcode", detail: xcodeOK ? detail("xcode") : detail("xcode"), button: xcodeOK ? nil : button, enabled: setupBusy == nil)
        case .metal:
            let ok = state("metal") == "ok"
            return RequirementRow(ok: ok, title: "Metal Toolchain", detail: ok ? "Apple's graphics compiler is installed." : "Apple's graphics compiler, a download of a few GB.", button: ok ? nil : "Install", enabled: xcodeOK && setupBusy == nil)
        case .tools:
            let miss = toolsMissing
            return RequirementRow(ok: miss.isEmpty, title: "Build tools", detail: miss.isEmpty ? "uv, zstd and glslang are installed." : "To install: \(miss.joined(separator: ", ")). They go in Bowshot's own folder.", button: miss.isEmpty ? nil : "Install", enabled: xcodeOK && setupBusy == nil)
        }
    }

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
        var states: [String: [String]] = [:]
        for line in output.components(separatedBy: "\n") {
            let p = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            if p.count == 3 { states[p[0]] = [p[1], p[2]] }
        }
        setupStates = states
        let first = !checked
        checked = true
        if first && setupReady && step == .setup { step = .game }   // nothing to install: the first screen is skipped
    }

    func perform(_ r: Requirement) {
        switch r {
        case .xcode:
            switch state("xcode") {
            case "manual": if let url = URL(string: "https://apps.apple.com/app/xcode/id497799835") { NSWorkspace.shared.open(url) }
            case "firstlaunch":
                let apps = ((try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []).filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }.sorted()
                if let app = apps.last { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/" + app)) }
            case "select": runSetup(["--select-xcode"], title: "Selecting Xcode…")
            default: break
            }
        case .metal: runSetup(["--install", "metal"], title: "Downloading the Metal Toolchain…")
        case .tools: runSetup(["--install", "tools"], title: "Installing the build tools…")
        }
    }

    // One setup step: the script's output goes to the log, and the Mac is checked again when it ends
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
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setupProcess = nil; self.setupBusy = nil; self.append("", flush: true)
                self.refreshSetup()
            }
        }
        appendLine("— \(title)")
        do { try task.run(); setupProcess = task; setupBusy = title }
        catch { appendLine("ERROR: Could not start the setup: \(error.localizedDescription)") }
    }

    // MARK: - Game folder

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "Choose your own dump folder, outside any Git repository."
        if panel.runModal() == .OK, let url = panel.url { folder = url.path }
    }

    // A dropped folder is the game folder; a dropped file stands for the folder it is in
    func drop(_ url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        folder = isDir.boolValue ? url.path : url.deletingLastPathComponent().path
    }

    // Why the chosen folder cannot be built, nil when it can: the checks bowshot_build.sh makes first (it exists, it is outside any Git repository and outside the
    // builder), and that it holds a game: a .nup, NSP / XCI files (.nsp .nsz .xci .xcz) or a dump (base/). The script still checks the game and its update itself
    var folderProblem: String? {
        let path = folder
        let fm = FileManager.default; var isDir: ObjCBool = false
        guard !path.isEmpty else { return "Choose a folder containing your own game." }
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

    var gameFiles: String {   // what the folder holds, for the game screen
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        let games = names.filter { !$0.hasPrefix("._") && ["nup", "nsp", "nsz", "xci", "xcz"].contains(($0 as NSString).pathExtension.lowercased()) }
        if games.count == 1 { return games[0] }
        if games.count > 1 { return "\(games.count) game files" }
        return "A game dump (base folder)"
    }

    // MARK: - Log

    // The log, line by line: bowshot_build.sh's blocking errors (ERROR: ) in red, the engine's warnings ([RED] ) in orange, the finished app (READY: and the line
    // after it) in green, everything else in the text colour
    func append(_ text: String, flush: Bool = false) {
        pending += text
        var lines = pending.components(separatedBy: "\n")
        let tail = lines.removeLast()
        for line in lines { appendLine(line) }
        if flush { if !tail.isEmpty { appendLine(tail) }; pending = "" } else { pending = tail }
    }

    func appendLine(_ line: String) {
        if line.hasPrefix("{"), let data = line.data(using: .utf8), let e = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], e["ev"] != nil { handleEvent(e); return }
        let color: NSColor
        if line.hasPrefix("ERROR: ") { color = .systemRed; sawError = true; if failure.isEmpty { failure = String(line.dropFirst(7)) } }
        else if line.hasPrefix("READY: ") || readyNext { color = .systemGreen }
        else if line.hasPrefix("[RED] ") { color = .systemOrange }
        else { color = .textColor }
        readyNext = line.hasPrefix("READY: ")
        lastBeat = Date()
        let start = log.length
        log.append(NSAttributedString(string: line + "\n", attributes: [.foregroundColor: color, .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]))
        if line.hasPrefix("[RED] ") { lastWarning = NSRange(location: start, length: (line as NSString).length) }
    }

    // MARK: - Progress

    func clock(_ seconds: Double) -> String {
        let t = Int(seconds), h = t / 3600, m = t % 3600 / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // About how long is left, from the engine's estimate in seconds
    func left(_ eta: Double) -> String {
        if eta < 60 { return "less than a minute left" }
        let m = Int((eta / 60).rounded())
        return m < 60 ? "about \(m) min left" : "about \(m / 60) h \(String(format: "%02d", m % 60)) min left"
    }

    func newStep() { stepStart = Date(); lastBeat = stepStart; curFrac = 0; countText = "" }

    // The whole build's progress: the stages done, plus the share of the current one (the game app is the last stage, made of the engine's own stages)
    func updateFraction() {
        guard stage.n > 0 else { fraction = 0; return }
        var sub = curFrac
        if appPart { sub = inner.n > 0 ? (Double(inner.k - 1) + curFrac) / Double(inner.n) : 0 }
        fraction = min((Double(stage.k - 1) + sub) / Double(stage.n), 0.999)
    }

    func showStage() {
        stageTitle = stage.name
        stageIndex = "Step \(stage.k) of \(stage.n)"
        let step = stage.step
        stageDetail = [step, countText].filter { !$0.isEmpty }.joined(separator: " · ")
        updateFraction()
    }

    // The engine's progress (build_ipa_from_nsp.py --progress json): stage, step, progress and stage_end move the bar and the step line; say is a message for the log
    func handleEvent(_ e: [String: Any]) {
        let ev = e["ev"] as? String ?? ""
        switch ev {
        case "bowshot_part":   // the second part: one step of its own, after the first part's stages
            appPart = true; newStep()
            stage = (firstStages + 1, firstStages + 1, e["name"] as? String ?? "Game app", "preparing")
            inner = (0, 0, "")
            showStage()
            appendLine("[\(stage.k)/\(stage.n)] \(stage.name) …")
        case "stage":
            let k = e["k"] as? Int ?? 0, n = e["n"] as? Int ?? 0, name = e["name"] as? String ?? "", step = e["step"] as? String ?? ""
            newStep()
            if appPart {
                inner = (k, n, name); stage.step = step.isEmpty ? name : "\(name) · \(step)"
                showStage()
                appendLine("[\(stage.k)/\(stage.n)] \(stage.name) · \(stage.step) …")
            } else {
                firstStages = n
                stage = (k, n + 1, name, step)   // + 1: the second part, still to come
                showStage()
                appendLine("[\(stage.k)/\(stage.n)] \(stage.name)" + (stage.step.isEmpty ? "" : " · \(stage.step)") + " …")
            }
        case "step":
            let step = e["step"] as? String ?? ""
            newStep()
            stage.step = appPart ? (step.isEmpty ? inner.name : "\(inner.name) · \(step)") : step
            showStage()
            appendLine("[\(stage.k)/\(stage.n)] \(stage.name) · \(stage.step) …")
        case "progress":
            curFrac = e["frac"] as? Double ?? curFrac
            var parts: [String] = []
            if let d = e["done"] as? Double, let t = e["total"] as? Double, t > 0, (e["unit"] as? String ?? "") != "" {   // the count: "4,887/8,345 lines"
                let nf = NumberFormatter(); nf.numberStyle = .decimal
                parts.append("\(nf.string(from: NSNumber(value: Int(d))) ?? "")/\(nf.string(from: NSNumber(value: Int(t))) ?? "") \(e["unit"] as? String ?? "")")
            }
            if let note = e["note"] as? String, !note.isEmpty { parts.append(note) }
            if let eta = e["eta"] as? Double { parts.append(left(eta)) }
            countText = parts.joined(separator: " · ")
            showStage()
        case "stage_end":
            let ok = e["ok"] as? Bool ?? true, warn = e["warn"] as? Bool ?? false
            let sec = Int(e["elapsed"] as? Double ?? 0), summary = e["summary"] as? String ?? ""
            let mark = warn ? "⚠" : ok ? "✓" : "✗", time = "\(sec / 60):\(String(format: "%02d", sec % 60))"
            curFrac = 1
            if appPart {
                updateFraction()
                appendLine("\(mark) [\(stage.k)/\(stage.n)] \(stage.name) · \(inner.name) (\(time))" + (summary.isEmpty ? "" : ": \(summary)"))
            } else {
                updateFraction()
                appendLine("\(mark) [\(stage.k)/\(stage.n)] \(stage.name) (\(time))" + (summary.isEmpty ? "" : ": \(summary)"))
            }
        case "say":
            for l in (e["msg"] as? String ?? "").components(separatedBy: "\n") { appendLine(l) }
        case "game":
            appendLine("Game: \(e["name"] as? String ?? "?") \(e["version"] as? String ?? "")")
        default: break
        }
    }

    // Every second while a build runs: the elapsed time moves, and a step that has logged nothing for a minute says it is still running
    func tick() {
        guard process != nil else { return }
        elapsed = Date().timeIntervalSince(buildStart)
        if stage.k > 0, Date().timeIntervalSince(lastBeat) >= 60 {
            appendLine("  … \(stage.name) still running, \(clock(Date().timeIntervalSince(stepStart))) in this step" + (countText.isEmpty ? "" : " (\(countText))"))
        }
    }

    func playDone() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("BuildDone.mp3")
        let sound = url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? NSSound(contentsOf: $0, byReference: true) : nil } ?? NSSound(named: "Glass")
        sound?.play()
    }

    // MARK: - Build

    var appURL: URL? { output?.appendingPathComponent("Ocarina of Time.app") }

    func startBuild() {
        guard process == nil, setupProcess == nil, setupReady, folderProblem == nil else { return }
        guard let resources = Bundle.main.resourceURL else { fail("The app resources are missing."); return }
        let test = ProcessInfo.processInfo.environment["BOWSHOT_BUILD_SCRIPT"]   // interface test: a script that plays the engine's events
        let script = test.map { URL(fileURLWithPath: $0) } ?? resources.appendingPathComponent("engine/scripts/bowshot_build.sh")
        guard FileManager.default.fileExists(atPath: script.path) else { fail("Builder files are missing; use a complete release archive."); return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path, "--build", folder]
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
            DispatchQueue.main.async { self?.buildEnded(status: finished.terminationStatus) }
        }
        output = URL(fileURLWithPath: folder).appendingPathComponent("Bowshot-local")
        log.setAttributedString(NSAttributedString()); pending = ""; lastWarning = nil; sawError = false; readyNext = false
        stage = (0, 0, "", ""); firstStages = 0; appPart = false; inner = (0, 0, ""); curFrac = 0; countText = ""
        stageTitle = "Starting…"; stageIndex = ""; stageDetail = ""; fraction = 0; elapsed = 0; failed = false; failure = ""
        buildStart = Date(); lastBeat = buildStart; stepStart = buildStart
        do {
            try task.run(); process = task; building = true; step = .build
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        } catch { fail("Could not start the builder: \(error.localizedDescription)") }
    }

    func fail(_ message: String) { failed = true; failure = message; step = .build }

    func buildEnded(status: Int32) {
        process = nil; building = false
        ticker?.invalidate(); ticker = nil
        append("", flush: true)
        elapsed = Date().timeIntervalSince(buildStart)
        if status == 0 {
            if appPart {
                let sec = Int(Date().timeIntervalSince(stepStart))
                appendLine("✓ [\(stage.k)/\(stage.n)] \(stage.name) (\(sec / 60):\(String(format: "%02d", sec % 60)))")
            }
            fraction = 1; finishedIn = elapsed
            step = .done
            playDone()
        } else {
            failed = true
            if let r = lastWarning, NSMaxRange(r) <= log.length {   // the engine's reason, shown in red
                log.addAttribute(.foregroundColor, value: NSColor.systemRed, range: r)
                let reason = (log.string as NSString).substring(with: r).replacingOccurrences(of: "[RED] ", with: "")
                if failure.isEmpty || !sawError { failure = reason.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if failure.isEmpty { failure = "The build stopped (exit \(status)) without a message. The full log is build.log in Bowshot-local." }
            if !sawError && lastWarning == nil { appendLine("ERROR: The build stopped (exit \(status)) without a message. The full log is build.log in Bowshot-local.") }
        }
    }

    func showOutput() { if let url = output { NSWorkspace.shared.open(url) } }
    func showApp() { if let url = appURL, FileManager.default.fileExists(atPath: url.path) { NSWorkspace.shared.activateFileViewerSelecting([url]) } else { showOutput() } }
    func openGame() { if let url = appURL { NSWorkspace.shared.open(url) } }
    func buildAgain() { failed = false; failure = ""; step = .game }
}
