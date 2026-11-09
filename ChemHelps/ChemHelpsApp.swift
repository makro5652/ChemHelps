import AppKit
import Combine
import SwiftUI

@main
enum ChemHelpsApp {
    @MainActor
    static func main() {
        if IconRenderer.runIfRequested() { return }
        if Snapshot.runIfRequested() { return }
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let didShowPanelKey = "didShowPanel"

    private var statusItem: NSStatusItem?
    private var hotkeys: GlobalHotkeys?
    private var activationObserver: NSObjectProtocol?

    private lazy var writer: WriterPanel = WriterPanel(rootView: WriterView(
        state: .shared,
        onInsert: { [weak self] text in self?.insert(text) },
        onCopy: { [weak self] text in self?.copy(text) },
        onOpenTable: { [weak self] in self?.showTable() },
        onOpenMolecule: { [weak self] in self?.showMolecule() }
    ))

    private lazy var table: ToolWindow = ToolWindow(
        rootView: PeriodicTableView(onClose: { [weak self] in self?.close(self?.table) }),
        defaultSize: Self.tableSize(),
        autosaveName: "Periodensystem",
        transparent: false
    )

    private lazy var molecule: ToolWindow = ToolWindow(
        rootView: MoleculeOverlayView(state: .shared, onClose: { [weak self] in self?.close(self?.molecule) }),
        defaultSize: CGSize(width: 620, height: 560),
        autosaveName: "Molekuel",
        transparent: true
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "flask", accessibilityDescription: "ChemHelps")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        hotkeys = GlobalHotkeys { [weak self] action in
            guard let self else { return }
            switch action {
            case .openWriter: toggleWriter()
            case .convertSelection: convertSelection()
            case .periodicTable: table.isVisible ? close(table) : showTable()
            case .molecule: molecule.isVisible ? close(molecule) : showMolecule()
            }
        }

        // Nach dem Erteilen der Freigabe in den Systemeinstellungen den Hinweis aktualisieren.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { WriterState.shared.refreshAccess() }
        }

        if !UserDefaults.standard.bool(forKey: Self.didShowPanelKey) {
            UserDefaults.standard.set(true, forKey: Self.didShowPanelKey)
            showWriter()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWriter()
        return false
    }

    /// Groß genug für den Beamer: drei Viertel der Bildschirmbreite.
    private static func tableSize() -> CGSize {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let width = min(visible.width * 0.78, visible.height * 0.92 * 18 / 10.6)
        return CGSize(width: width, height: width * 10.6 / 18)
    }

    // MARK: Menüleiste

    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showStatusMenu()
        } else {
            toggleWriter()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        for (title, action, hotkey) in [
            ("Formelschreiber", #selector(openWriter), HotkeyAction.openWriter),
            ("Periodensystem", #selector(openTable), HotkeyAction.periodicTable),
            ("3D-Molekül", #selector(openMolecule), HotkeyAction.molecule),
        ] {
            let item = NSMenuItem(title: "\(title)    \(hotkey.displayString)", action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "ChemHelps beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openWriter() { showWriter() }
    @objc private func openTable() { showTable() }
    @objc private func openMolecule() { showMolecule() }

    // MARK: Fenster

    private func toggleWriter() {
        if writer.isVisible { writer.orderOut(nil) } else { showWriter() }
    }

    private func showWriter() {
        WriterState.shared.refreshAccess()
        writer.place(below: statusItem?.button?.window?.frame)
        writer.orderFrontRegardless()
        writer.makeKey()
        WriterState.shared.focusRequest += 1
    }

    /// Periodensystem und Molekül aktivieren die App, damit Maus und Tastatur sofort reagieren.
    private func showTable() {
        writer.orderOut(nil)
        NSApp.activate()
        table.makeKeyAndOrderFront(nil)
    }

    private func showMolecule() {
        writer.orderOut(nil)
        NSApp.activate()
        molecule.makeKeyAndOrderFront(nil)
        MoleculeState.shared.focusRequest += 1
    }

    /// Ohne weitere offene Fenster geht der Fokus an die vorherige App zurück.
    private func close(_ window: NSWindow?) {
        window?.orderOut(nil)
        if !table.isVisible, !molecule.isVisible { NSApp.hide(nil) }
    }

    // MARK: Formeln einfügen

    private func insert(_ text: String) {
        let state = WriterState.shared
        state.remember(text)
        writer.orderOut(nil)
        Task {
            // Ist ChemHelps selbst aktiv (Periodensystem offen), zuerst zur vorherigen App wechseln.
            if NSApp.isActive {
                NSApp.hide(nil)
                try? await Task.sleep(for: .milliseconds(200))
            }
            try? await Task.sleep(for: .milliseconds(80))
            if await TextInserter.insert(text) {
                state.input = ""
            } else {
                state.show("Kopiert – mit ⌘V einfügen.")
                flashStatusIcon()
            }
        }
    }

    private func copy(_ text: String) {
        TextInserter.copy(text)
        WriterState.shared.remember(text)
        WriterState.shared.show("In die Zwischenablage kopiert.")
    }

    /// ⌃⌥⌘K: markierten Text in der App im Vordergrund umwandeln.
    private func convertSelection() {
        guard TextInserter.canSendKeys else {
            TextInserter.requestAccess()
            showWriter()
            WriterState.shared.show("Für ⌃⌥⌘K braucht die App die Freigabe „Bedienungshilfen“.")
            return
        }
        Task {
            await waitForModifierRelease()
            guard let selection = await TextInserter.copySelection() else {
                NSSound.beep()
                return
            }
            let converted = FormulaConverter.convert(selection.text)
            guard converted != selection.text else {
                TextInserter.restorePasteboard(selection.saved)
                NSSound.beep()
                return
            }
            await TextInserter.replaceSelection(with: converted, restoring: selection.saved)
            WriterState.shared.remember(converted)
        }
    }

    /// Solange ⌃ oder ⌥ vom Kurzbefehl noch gedrückt sind, käme ⌘C als ⌃⌥⌘C an.
    private func waitForModifierRelease() async {
        for _ in 0..<40 {
            if NSEvent.modifierFlags.isDisjoint(with: [.control, .option, .shift]) { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func flashStatusIcon() {
        guard let button = statusItem?.button else { return }
        let original = button.image
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Kopiert")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            button.image = original
        }
    }
}

/// Schwebendes Formelfenster unter dem Menüleisten-Symbol. Es aktiviert die App nicht,
/// sodass die vorherige App im Vordergrund bleibt und das Ergebnis dort eingefügt werden kann.
@MainActor
final class WriterPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        let host = NSHostingController(rootView: rootView)
        host.sizingOptions = [.preferredContentSize]
        contentViewController = host
        setContentSize(host.view.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    func place(below statusFrame: CGRect?) {
        guard !isVisible else { return }
        let screens = NSScreen.screens
        let screen = screens.first { screen in
            statusFrame.map { screen.frame.contains(CGPoint(x: $0.midX, y: $0.midY)) } ?? false
        } ?? NSScreen.main ?? screens[0]
        let visible = screen.visibleFrame
        let anchor = statusFrame.flatMap { $0.minY >= visible.maxY - 1 ? $0 : nil }
        let width = frame.width
        let x = min((anchor?.midX ?? visible.maxX) - width / 2, visible.maxX - width - 12)
        setFrameTopLeftPoint(CGPoint(x: max(x, visible.minX + 12), y: visible.maxY - 6))
    }
}

/// Großes schwebendes Fenster für Periodensystem und Molekül: in der Größe veränderbar,
/// auch über Vollbild-Präsentationen. Position und Größe bleiben erhalten.
@MainActor
final class ToolWindow: NSPanel {
    init(rootView: some View, defaultSize: CGSize, autosaveName: String, transparent: Bool) {
        super.init(
            contentRect: CGRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = !transparent
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        if transparent {
            isOpaque = false
            backgroundColor = .clear
            hasShadow = false
        } else {
            isOpaque = false
            backgroundColor = .clear
        }
        minSize = CGSize(width: 420, height: 320)
        let host = NSHostingView(rootView: rootView)
        contentView = host
        center()
        setFrameAutosaveName(autosaveName)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
        if !(NSApp.windows.contains { $0 is ToolWindow && $0.isVisible }) { NSApp.hide(nil) }
    }
}
