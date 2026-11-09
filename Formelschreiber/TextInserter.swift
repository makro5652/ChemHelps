import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Schreibt Text in die App im Vordergrund, indem er über die Zwischenablage eingefügt wird.
/// Das Senden von ⌘C und ⌘V braucht die Freigabe unter Datenschutz › Bedienungshilfen;
/// ohne sie landet das Ergebnis nur in der Zwischenablage.
@MainActor
enum TextInserter {
    static var canSendKeys: Bool { AXIsProcessTrusted() }

    /// Öffnet die Systemabfrage für die Freigabe.
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func copy(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    /// Fügt Text ein und stellt danach die vorherige Zwischenablage wieder her.
    /// Gibt false zurück, wenn nur kopiert werden konnte.
    @discardableResult
    static func insert(_ text: String) async -> Bool {
        guard canSendKeys else {
            copy(text)
            return false
        }
        let saved = savePasteboard()
        copy(text)
        try? await Task.sleep(for: .milliseconds(60))
        pressCommand(kVK_ANSI_V)
        try? await Task.sleep(for: .milliseconds(350))
        restorePasteboard(saved)
        return true
    }

    /// Kopiert die Auswahl der App im Vordergrund. Nil, wenn nichts ausgewählt ist oder die Freigabe fehlt.
    static func copySelection() async -> (text: String, saved: [[NSPasteboard.PasteboardType: Data]])? {
        guard canSendKeys else { return nil }
        let board = NSPasteboard.general
        let saved = savePasteboard()
        let before = board.changeCount
        pressCommand(kVK_ANSI_C)
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            if board.changeCount != before { break }
        }
        guard board.changeCount != before, let text = board.string(forType: .string), !text.isEmpty else {
            restorePasteboard(saved)
            return nil
        }
        return (text, saved)
    }

    static func replaceSelection(with text: String, restoring saved: [[NSPasteboard.PasteboardType: Data]]) async {
        copy(text)
        try? await Task.sleep(for: .milliseconds(40))
        pressCommand(kVK_ANSI_V)
        try? await Task.sleep(for: .milliseconds(350))
        restorePasteboard(saved)
    }

    // MARK: Hilfen

    private static func pressCommand(_ key: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private static func savePasteboard() -> [[NSPasteboard.PasteboardType: Data]] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }
    }

    static func restorePasteboard(_ items: [[NSPasteboard.PasteboardType: Data]]) {
        let board = NSPasteboard.general
        board.clearContents()
        let restored = items.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
    }
}
