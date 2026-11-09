import AppKit
import Combine
import SwiftUI

@main
enum FormelschreiberApp {
    @MainActor
    static func main() {
        if IconRenderer.runIfRequested() { return }
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
    private lazy var panel: WriterPanel = WriterPanel(
        onInsert: { [weak self] text in self?.insert(text) },
        onCopy: { [weak self] text in self?.copy(text) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "flask", accessibilityDescription: "Formelschreiber")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        hotkeys = GlobalHotkeys { [weak self] action in
            switch action {
            case .openWriter: self?.togglePanel()
            case .convertSelection: self?.convertSelection()
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
            showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    // MARK: Fenster

    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Formelfenster öffnen", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Formelschreiber beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openPanel() { showPanel() }

    private func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }

    private func showPanel() {
        WriterState.shared.refreshAccess()
        panel.place(below: statusItem?.button?.window?.frame)
        panel.orderFrontRegardless()
        panel.makeKey()
        WriterState.shared.focusRequest += 1
    }

    // MARK: Aktionen

    private func insert(_ text: String) {
        let state = WriterState.shared
        state.remember(text)
        panel.orderOut(nil)
        Task {
            // Kurz warten, bis die vorherige App wieder Tastatureingaben bekommt.
            try? await Task.sleep(for: .milliseconds(80))
            if await TextInserter.insert(text) {
                state.input = ""
            } else {
                state.show("Kopiert – mit ⌘V einfügen.")
                notify("Kopiert – mit ⌘V einfügen")
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
            showPanel()
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

    private func notify(_ text: String) {
        guard let button = statusItem?.button else { return }
        let original = button.image
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: text)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            button.image = original
        }
    }
}

/// Schwebendes Fenster unter dem Menüleisten-Symbol. Es aktiviert die App nicht,
/// sodass die vorherige App im Vordergrund bleibt und das Ergebnis dort eingefügt werden kann.
@MainActor
final class WriterPanel: NSPanel {
    init(onInsert: @escaping (String) -> Void, onCopy: @escaping (String) -> Void) {
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
        let host = NSHostingController(rootView: WriterView(state: .shared, onInsert: onInsert, onCopy: onCopy))
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
