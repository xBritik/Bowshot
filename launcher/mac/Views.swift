// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

// The builder is a guided flow of four screens (Your Mac, Game, Build, Done): a step bar on top, one screen, and its actions at the foot.
// System parts only (bordered buttons, progress bars, grouped rows); 20 pt margins, 8 pt between related things.
let margin: CGFloat = 20

struct ContentView: View {
    @ObservedObject var m: BuilderModel

    var body: some View {
        VStack(spacing: 0) {
            StepBar(current: m.step).padding(.horizontal, margin).padding(.vertical, 14)
            Divider()
            Group {
                switch m.step {
                case .setup: SetupScreen(m: m)
                case .game: GameScreen(m: m)
                case .build: BuildScreen(m: m)
                case .done: DoneScreen(m: m)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 540)
        .animation(.easeInOut(duration: 0.2), value: m.step)
    }
}

// MARK: - Step bar

struct StepBar: View {
    let current: Step
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(s.rawValue < current.rawValue ? Color.accentColor : Color.clear)
                        Circle().strokeBorder(s.rawValue <= current.rawValue ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        if s.rawValue < current.rawValue {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        } else {
                            Text("\(s.rawValue + 1)").font(.caption.weight(.semibold)).foregroundStyle(s == current ? Color.accentColor : Color.secondary)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(s.title).font(.callout.weight(s == current ? .semibold : .regular)).foregroundStyle(s == current ? .primary : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(s.rawValue + 1), \(s.title)" + (s == current ? ", current" : s.rawValue < current.rawValue ? ", done" : ""))
                if s != Step.allCases.last { Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1).frame(maxWidth: .infinity) }
            }
        }
    }
}

// MARK: - Shared parts

struct ScreenHeader: View {
    let image: String
    let tint: Color
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: image).font(.system(size: 36, weight: .regular)).foregroundStyle(tint).accessibilityHidden(true)
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 480)
    }
}

// The actions of a screen, at its foot: the secondary one on the left, the main one on the right
struct Footer<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack { leading; Spacer(); trailing }.padding(margin)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.secondary.opacity(0.25)))
    }
}

// The log: selectable and copyable (Command-C reaches it through the Edit menu), errors in red, warnings in orange
struct LogView: NSViewRepresentable {
    let storage: NSTextStorage

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let text = scroll.documentView as! NSTextView
        text.layoutManager?.replaceTextStorage(storage)
        text.isEditable = false; text.isSelectable = true; text.usesFindBar = true
        text.backgroundColor = .textBackgroundColor
        text.textContainerInset = NSSize(width: 6, height: 6)
        context.coordinator.text = text
        context.coordinator.observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: storage, queue: .main) { [weak text] _ in
            DispatchQueue.main.async { text?.scrollToEndOfDocument(nil) }   // not inside the edit: scrolling there makes the layout manager generate glyphs mid-edit, which throws
        }
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        var text: NSTextView?
        var observer: NSObjectProtocol?
        deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    }
}

struct LogDisclosure: View {
    @ObservedObject var m: BuilderModel
    @Binding var open: Bool
    var height: CGFloat = 150
    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            LogView(storage: m.log)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.secondary.opacity(0.25)))
                .padding(.top, 8)
        } label: {
            Text(open ? "Hide details" : "Show details").font(.callout)
        }
    }
}

// MARK: - 1. Your Mac

struct SetupScreen: View {
    @ObservedObject var m: BuilderModel
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: margin) {
                    ScreenHeader(image: "wrench.and.screwdriver", tint: .accentColor, title: "Set up your Mac",
                                 subtitle: "Bowshot needs a few tools, once. Each one installs with a single click. No Terminal needed.")
                    if !m.checked {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Checking your Mac…").foregroundStyle(.secondary) }
                    } else {
                        Card {
                            ForEach(Array(Requirement.allCases.enumerated()), id: \.element) { i, r in
                                RequirementLine(m: m, r: r)
                                if i < Requirement.allCases.count - 1 { Divider().padding(.leading, 56) }
                            }
                        }
                        .frame(maxWidth: 560)
                        if let busy = m.setupBusy {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(busy).foregroundStyle(.secondary) }.frame(maxWidth: 560, alignment: .leading)
                        }
                        LogDisclosure(m: m, open: $showLog).frame(maxWidth: 560)
                    }
                }
                .padding(margin)
                .frame(maxWidth: .infinity)
            }
            Footer {
                Button("Check Again") { m.refreshSetup() }.disabled(m.setupBusy != nil)
            } trailing: {
                Button("Continue") { m.step = .game }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!m.setupReady)
            }
        }
        .onChange(of: m.setupBusy) { _, busy in if busy != nil { showLog = true } }
    }
}

struct RequirementLine: View {
    @ObservedObject var m: BuilderModel
    let r: Requirement
    var body: some View {
        let row = m.row(r)
        HStack(spacing: 12) {
            Image(systemName: row.ok ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 22)).foregroundStyle(row.ok ? Color.green : Color.secondary)
                .frame(width: 32).accessibilityLabel(row.ok ? "Ready" : "Not ready")
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.headline)
                Text(row.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let b = row.button { Button(b) { m.perform(r) }.disabled(!row.enabled) }
            else if !row.ok && m.setupBusy != nil { ProgressView().controlSize(.small) }
        }
        .padding(12)
    }
}

// MARK: - 2. Game

struct GameScreen: View {
    @ObservedObject var m: BuilderModel
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: margin) {
                    ScreenHeader(image: "shippingbox", tint: .accentColor, title: "Choose your game",
                                 subtitle: "Pick the folder with your own copy of Ocarina of Time (Switch 2, update v131072): one .nup file, or the .nsp files.")
                    if m.folder.isEmpty { DropZone(m: m, targeted: targeted) } else { ChosenFolder(m: m) }
                    Card {
                        Fact(symbol: "clock", text: "The first build takes 1.5 hours or more. Later builds are much faster.")
                        Divider().padding(.leading, 44)
                        Fact(symbol: "bolt.fill", text: "Keep your Mac plugged in, and leave this window open. You can use other apps.")
                        Divider().padding(.leading, 44)
                        Fact(symbol: "internaldrive", text: "About 100 GB of free space is needed. Everything stays on your Mac, in this folder.")
                    }
                    .frame(maxWidth: 560)
                }
                .padding(margin)
                .frame(maxWidth: .infinity)
            }
            Footer {
                Button("Back") { m.step = .setup }
            } trailing: {
                Button("Build My Local Game") { m.startBuild() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(m.folderProblem != nil || !m.setupReady)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in if let url = url { DispatchQueue.main.async { m.drop(url) } } }
            return true
        }
        .onAppear { m.refreshSetup() }
    }
}

struct DropZone: View {
    @ObservedObject var m: BuilderModel
    let targeted: Bool
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc").font(.system(size: 26)).foregroundStyle(.secondary).accessibilityHidden(true)
            Text("Drop your game folder here").font(.headline)
            Button("Choose Folder…") { m.chooseFolder() }
        }
        .frame(maxWidth: 560, minHeight: 130)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(targeted ? Color.accentColor.opacity(0.12) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }
}

struct ChosenFolder: View {
    @ObservedObject var m: BuilderModel
    var body: some View {
        let problem = m.folderProblem
        Card {
            HStack(spacing: 12) {
                Image(systemName: problem == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22)).foregroundStyle(problem == nil ? Color.green : Color.orange)
                    .frame(width: 32).accessibilityLabel(problem == nil ? "Game found" : "Problem")
                VStack(alignment: .leading, spacing: 2) {
                    Text(problem == nil ? m.gameFiles : "This folder cannot be used").font(.headline).lineLimit(1).truncationMode(.middle)
                    Text(problem ?? (m.folder as NSString).abbreviatingWithTildeInPath).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(3).truncationMode(.middle).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Change…") { m.chooseFolder() }
            }
            .padding(12)
        }
        .frame(maxWidth: 560)
    }
}

struct Fact: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 32).accessibilityHidden(true)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

// MARK: - 3. Build

struct BuildScreen: View {
    @ObservedObject var m: BuilderModel
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: margin) {
                    if m.failed {
                        ScreenHeader(image: "exclamationmark.octagon.fill", tint: .red, title: "The build stopped",
                                     subtitle: m.failure.isEmpty ? "Something went wrong. The details below say what." : m.failure)
                    } else {
                        ScreenHeader(image: "hammer", tint: .accentColor, title: "Building your game",
                                     subtitle: "This runs on your Mac and can take a long while. Keep it plugged in and this window open.")
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(m.stageTitle).font(.headline)
                                Spacer()
                                Text(m.stageIndex).font(.callout).foregroundStyle(.secondary)
                            }
                            ProgressView(value: m.fraction).progressViewStyle(.linear)
                                .accessibilityLabel("Build progress").accessibilityValue("\(Int(m.fraction * 100)) percent")
                            HStack(alignment: .firstTextBaseline) {
                                Text(m.stageDetail.isEmpty ? " " : m.stageDetail).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                                Spacer()
                                Text("\(Int(m.fraction * 100)) % · \(m.clock(m.elapsed)) elapsed").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: 560)
                    }
                    LogDisclosure(m: m, open: $showLog, height: m.failed ? 220 : 160).frame(maxWidth: 560)
                }
                .padding(margin)
                .frame(maxWidth: .infinity)
            }
            if m.failed {
                Footer {
                    Button("Back to Game") { m.buildAgain() }
                } trailing: {
                    Button("Try Again") { m.startBuild() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            } else {
                Footer {
                    Text("Closing the window does not stop the build.").font(.callout).foregroundStyle(.secondary)
                } trailing: { EmptyView() }
            }
        }
        .onChange(of: m.failed) { _, failed in if failed { showLog = true } }
    }
}

// MARK: - 4. Done

struct DoneScreen: View {
    @ObservedObject var m: BuilderModel
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: margin) {
                Spacer(minLength: 0)
                ScreenHeader(image: "checkmark.seal.fill", tint: .green, title: "Your game is ready",
                             subtitle: "Ocarina of Time.app is in the Bowshot-local folder, inside your game folder. Built in \(m.clock(m.finishedIn)).")
                Card {
                    Fact(symbol: "lock.fill", text: "This app contains your game. Keep it private and do not upload it.")
                    Divider().padding(.leading, 44)
                    Fact(symbol: "arrow.down.app", text: "Drag it to your Applications folder if you like, or play it from where it is.")
                }
                .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
            .padding(margin)
            .frame(maxWidth: .infinity)
            Footer {
                Button("Build Again") { m.buildAgain() }
            } trailing: {
                HStack {
                    Button("Show in Finder") { m.showApp() }
                    Button("Open Game") { m.openGame() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}
