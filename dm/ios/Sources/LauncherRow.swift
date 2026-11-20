// One launcher setting as a row (a menu, a slider with its percentage, a toggle), shared by the iOS launcher (Launcher.swift) and the Mac app's settings window (dm/mac/Launcher.swift).
// A row whose setting is fixed by an env file or by the launch environment is shown but disabled.
import SwiftUI

extension LauncherModel {
    func binding(_ s: Setting) -> Binding<String> { Binding(get: { self.values[s.env] ?? s.def }, set: { self.values[s.env] = $0 }) }
}

struct SettingRow: View {
    let s: Setting
    @ObservedObject var m: LauncherModel

    private var locked: Bool { m.fixed.contains(s.env) }
    private var note: String {
        guard locked else { return s.note }
        return (s.note.isEmpty ? "" : s.note + " · ") + (m.fromLaunch.contains(s.env) ? "Set at launch" : "Set by an env file")
    }
    private var rangeValue: Binding<Double> {
        Binding(get: { Double(m.values[s.env] ?? s.def) ?? s.max ?? 1 },
                set: { m.values[s.env] = String(format: "%.4f", $0) })   // Bowshot: 4 decimals, so a twelfth step stays on its whole size (0.6667 of 1920x1080 = 1280x720, not 0.67)
    }
    private var percentage: String {   // Bowshot: "(default)" after the default value
        m.rangeLabel(s, rangeValue.wrappedValue) + (abs(rangeValue.wrappedValue - (Double(s.def) ?? .nan)) < 1e-4 ? " (default)" : "")
    }
    // Bowshot: a range's named values (Ocarina of Time's Potato, Normal, Native) as fractions of the slider's width, written under it at their steps
    private var markPlaces: [(name: String, at: Double)] {
        guard let marks = s.marks, let lo = s.min, let hi = s.max, hi > lo else { return [] }
        return marks.compactMap { mk in mk.count == 2 ? Double(mk[0]).map { (name: mk[1], at: ($0 - lo) / (hi - lo)) } : nil }.filter { $0.at >= 0 && $0.at <= 1 }
    }

    private var settingLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.label)
            if !note.isEmpty { Text(note).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    var body: some View {
        Group {
            switch s.kind {
            case "choice":
                Picker(selection: m.binding(s)) {
                    ForEach(offeredOptions(s, current: m.values[s.env]), id: \.[0]) { Text($0[1] + ($0[0] == s.def ? " (default)" : "")).tag($0[0]) }   // Bowshot: the default named
                } label: {
                    settingLabel
                }
                .pickerStyle(.menu)
            case "range":
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        settingLabel
                        Spacer()
                        Text(percentage).monospacedDigit().foregroundStyle(.secondary)
                    }
                    // Bowshot: the marks hang from the slider itself (an overlay as wide as its track), so they stay under their steps whatever width the form gives
                    // the slider: on the Mac a grouped Form puts it in the value column, narrower than the row. Labels hidden, it takes the row's whole width
                    Slider(value: rangeValue, in: (s.min ?? 0)...(s.max ?? 1), step: s.step ?? 0.05)
                        .labelsHidden()
                        .accessibilityLabel(s.label)
                        .accessibilityValue(percentage)
                        .padding(.bottom, markPlaces.isEmpty ? 0 : 16)
                        .overlay(alignment: .bottom) {
                            if !markPlaces.isEmpty {
                                GeometryReader { g in   // the thumb's centre, and the step ticks, stop about 10 points inside each end of the track
                                    ForEach(markPlaces.indices, id: \.self) { i in
                                        let at = markPlaces[i].at, last = at > 0.99
                                        // ▲ under its step: the name runs right from it, the last one's left (it ends at the track's end)
                                        Text(last ? markPlaces[i].name + " ▲" : "▲ " + markPlaces[i].name)
                                            .font(.caption2).foregroundStyle(.secondary).fixedSize()
                                            .frame(width: 0, alignment: last ? .trailing : .leading)
                                            .position(x: 10 + at * (g.size.width - 20) + (last ? 4 : -4), y: 7)
                                    }
                                }
                                .frame(height: 14)
                                .accessibilityHidden(true)
                            }
                        }
                }
            default:
                Toggle(isOn: Binding(get: { (m.values[s.env] ?? s.def) == s.onValue }, set: { m.values[s.env] = $0 ? s.onValue : s.offValue })) {
                    settingLabel
                }
            }
        }
        .disabled(locked)
    }
}
