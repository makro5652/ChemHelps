import AppKit
import Carbon.HIToolbox

/// Systemweite Kurzbefehle der App.
enum HotkeyAction: UInt32, CaseIterable {
    case openWriter = 1
    case convertSelection = 2

    var keyCode: UInt32 {
        switch self {
        case .openWriter: UInt32(kVK_ANSI_F)
        case .convertSelection: UInt32(kVK_ANSI_K)
        }
    }

    var modifiers: UInt32 { UInt32(controlKey | optionKey | cmdKey) }

    var displayString: String {
        switch self {
        case .openWriter: "⌃⌥⌘F"
        case .convertSelection: "⌃⌥⌘K"
        }
    }
}

/// Registriert die Kurzbefehle über die Carbon-Schnittstelle; das braucht keine Freigabe.
@MainActor
final class GlobalHotkeys {
    private static let signature = OSType(0x46_4F_52_4D) // "FORM"

    private let onPress: (HotkeyAction) -> Void
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private(set) var failed: [HotkeyAction] = []

    init(onPress: @escaping (HotkeyAction) -> Void) {
        self.onPress = onPress
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                guard status == noErr, let action = HotkeyAction(rawValue: identifier.id) else {
                    return OSStatus(eventNotHandledErr)
                }
                let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotkeys.onPress(action) }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
        for action in HotkeyAction.allCases {
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                action.keyCode, action.modifiers,
                EventHotKeyID(signature: Self.signature, id: action.rawValue),
                GetApplicationEventTarget(), 0, &reference
            )
            if status == noErr, let reference {
                references.append(reference)
            } else {
                failed.append(action)
            }
        }
    }
}
