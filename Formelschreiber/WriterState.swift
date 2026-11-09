import AppKit
import Combine

/// Eingabe, Verlauf und Statusmeldungen des Formelfensters.
@MainActor
final class WriterState: ObservableObject {
    static let shared = WriterState()

    private static let historyKey = "history"
    private static let historyLimit = 12

    @Published var input = ""
    @Published private(set) var history: [String]
    @Published var message: String?
    @Published var canSendKeys = TextInserter.canSendKeys
    /// Zählt hoch, wenn das Eingabefeld den Fokus bekommen soll.
    @Published var focusRequest = 0

    var output: String { FormulaConverter.convert(input) }

    private init() {
        history = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }

    func refreshAccess() {
        canSendKeys = TextInserter.canSendKeys
    }

    func show(_ text: String) {
        message = text
        let shown = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if self.message == shown { self.message = nil }
        }
    }
}
