import ServiceManagement
import SwiftUI

struct WriterView: View {
    @ObservedObject var state: WriterState
    /// Einfügen in die App im Vordergrund (schließt das Fenster).
    let onInsert: (String) -> Void
    let onCopy: (String) -> Void
    let onOpenTable: () -> Void
    let onOpenMolecule: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var showsHelp = false
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled

    private static let accent = Color(red: 0.36, green: 0.78, blue: 0.98)

    private static let symbols: [(String, String)] = [
        ("→", "Reaktionspfeil"), ("⇌", "Gleichgewicht"), ("↑", "Gas entweicht"), ("↓", "Niederschlag"),
        ("Δ", "Delta"), ("·", "Kristallwasser"), ("°", "Grad"), ("±", "plus/minus"),
        ("⁺", "hoch plus"), ("⁻", "hoch minus"), ("δ⁺", "Partialladung plus"), ("δ⁻", "Partialladung minus"),
        ("α", "alpha"), ("β", "beta"), ("γ", "gamma"), ("λ", "lambda"),
        ("μ", "mü"), ("π", "pi"), ("σ", "sigma"), ("≈", "ungefähr"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TextField("z. B. 2 H2 + O2 -> 2 H2O", text: $state.input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .lineLimit(1...4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.25)))
                .focused($inputFocused)
                .onSubmit(insert)

            preview

            HStack(spacing: 8) {
                Button(action: insert) {
                    Label(state.canSendKeys ? "Einfügen" : "Kopieren", systemImage: state.canSendKeys ? "text.insert" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Self.accent.opacity(0.8))
                .help(state.canSendKeys ? "In die vorherige App einfügen (↩)" : "In die Zwischenablage kopieren (↩)")
                Button {
                    copy(state.output)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Nur kopieren (⇧⌘C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button {
                    state.input = ""
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Eingabe leeren")
            }
            .disabled(state.input.trimmingCharacters(in: .whitespaces).isEmpty)
            .controlSize(.large)

            if let message = state.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            symbolGrid

            if !state.history.isEmpty { historyList }

            if !state.canSendKeys { accessHint }

            DisclosureGroup("Schreibweise", isExpanded: $showsHelp) { help }
                .font(.callout)

            Divider().opacity(0.5)
            footer
        }
        .padding(16)
        .frame(width: 360)
        .background {
            ZStack {
                VisualEffect()
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.15, blue: 0.27), Color(red: 0.09, green: 0.24, blue: 0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.75)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.15), value: state.message)
        .onAppear { inputFocused = true }
        .onChange(of: state.focusRequest) { inputFocused = true }
    }

    // MARK: Teile

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flask.fill")
                .foregroundStyle(Self.accent)
            Text("ChemHelps")
                .font(.headline)
            Spacer()
            Button(action: onOpenTable) {
                Image(systemName: "tablecells")
            }
            .buttonStyle(.borderless)
            .help("Periodensystem (\(HotkeyAction.periodicTable.displayString))")
            Button(action: onOpenMolecule) {
                Image(systemName: "atom")
            }
            .buttonStyle(.borderless)
            .help("3D-Molekül (\(HotkeyAction.molecule.displayString))")
            Menu {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { launchesAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                Button("Verlauf löschen") { state.clearHistory() }
                    .disabled(state.history.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var preview: some View {
        Text(state.input.isEmpty ? "2 H₂ + O₂ → 2 H₂O" : state.output)
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(state.input.isEmpty ? .tertiary : .primary)
            .textSelection(.enabled)
            .lineLimit(3)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
            ForEach(Self.symbols, id: \.0) { symbol, name in
                Button {
                    state.input += symbol
                    state.focusRequest += 1
                } label: {
                    Text(symbol)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Zuletzt")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(state.history.prefix(6), id: \.self) { entry in
                Button {
                    onInsert(entry)
                } label: {
                    Text(entry)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.06)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(state.canSendKeys ? "Erneut einfügen" : "Erneut kopieren")
            }
        }
    }

    private var accessHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ohne Freigabe wird nur kopiert. Zum direkten Einfügen und für ⌃⌥⌘K braucht die App „Bedienungshilfen“.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Freigabe erteilen …") {
                    TextInserter.requestAccess()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(.yellow.opacity(0.08)))
    }

    private var help: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
            helpRow("H2O, Ca(OH)2", "H₂O, Ca(OH)₂")
            helpRow("Na+, Fe3+, SO42-", "Na⁺, Fe³⁺, SO₄²⁻")
            helpRow("SO4^2-, ^14C", "SO₄²⁻, ¹⁴C")
            helpRow("C_n H_{2n+2}", "Cₙ H₂ₙ₊₂")
            helpRow("-> <=> <-", "→ ⇌ ←")
            helpRow("CO2 ^   AgCl _", "CO₂ ↑   AgCl ↓")
            helpRow("CuSO4*5H2O", "CuSO₄·5H₂O")
            helpRow("2e-, DeltaH, 25 degC", "2e⁻, ΔH, 25 °C")
            GridRow {
                Text("Kurzbefehle")
                    .foregroundStyle(.secondary)
                    .gridCellColumns(2)
                    .padding(.top, 4)
            }
            helpRow(HotkeyAction.openWriter.displayString, "dieses Fenster öffnen")
            helpRow(HotkeyAction.convertSelection.displayString, "markierten Text umwandeln")
            helpRow(HotkeyAction.periodicTable.displayString, "Periodensystem")
            helpRow(HotkeyAction.molecule.displayString, "3D-Molekül")
        }
        .font(.system(size: 12))
        .padding(.top, 6)
    }

    private func helpRow(_ input: String, _ result: String) -> some View {
        GridRow {
            Text(input).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            Text(result)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(HotkeyAction.openWriter.displayString) öffnet · \(HotkeyAction.convertSelection.displayString) wandelt Auswahl um")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Beenden", systemImage: "power")
            }
            .keyboardShortcut("q")
            .controlSize(.small)
            .help("ChemHelps beenden (⌘Q)")
        }
    }

    // MARK: Aktionen

    private func insert() {
        let text = state.output
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onInsert(text)
    }

    private func copy(_ text: String) {
        onCopy(text)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }
}
