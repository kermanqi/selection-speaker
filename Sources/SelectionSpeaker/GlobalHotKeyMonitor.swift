import Carbon
import Foundation

@MainActor
final class GlobalHotKeyMonitor {
    enum Action: UInt32 {
        case toggleReading = 1
        case toggleTranslation = 2
        case toggleTranslationDirection = 3
        case captureScreenText = 4
    }

    struct Registration {
        let action: Action
        let shortcut: HotKeyShortcut
    }

    private let onReadingToggle: @MainActor () -> Void
    private let onTranslationToggle: @MainActor () -> Void
    private let onTranslationDirectionToggle: @MainActor () -> Void
    private let onScreenTextCapture: @MainActor () -> Void
    private var registrations: [Registration]
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    init(
        registrations: [Registration],
        onReadingToggle: @escaping @MainActor () -> Void,
        onTranslationToggle: @escaping @MainActor () -> Void,
        onTranslationDirectionToggle: @escaping @MainActor () -> Void,
        onScreenTextCapture: @escaping @MainActor () -> Void
    ) {
        self.registrations = registrations
        self.onReadingToggle = onReadingToggle
        self.onTranslationToggle = onTranslationToggle
        self.onTranslationDirectionToggle = onTranslationDirectionToggle
        self.onScreenTextCapture = onScreenTextCapture
    }

    func start() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard parameterStatus == noErr else {
                    return parameterStatus
                }

                Task { @MainActor in
                    monitor.handleHotKey(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            throw GlobalHotKeyError.registrationFailed(status)
        }

        do {
            for registration in registrations {
                try register(registration)
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func register(_ registration: Registration) throws {
        var hotKey: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: registration.action.rawValue)
        let status = RegisterEventHotKey(
            registration.shortcut.keyCode,
            registration.shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        guard status == noErr, let hotKey else {
            throw GlobalHotKeyError.registrationFailed(status)
        }

        hotKeys.append(hotKey)
    }

    private func handleHotKey(id: UInt32) {
        switch Action(rawValue: id) {
        case .toggleReading:
            onReadingToggle()
        case .toggleTranslation:
            onTranslationToggle()
        case .toggleTranslationDirection:
            onTranslationDirectionToggle()
        case .captureScreenText:
            onScreenTextCapture()
        case nil:
            break
        }
    }

    private static let signature: OSType = {
        "SSHK".utf8.reduce(OSType(0)) { value, byte in
            (value << 8) + OSType(byte)
        }
    }()
}

enum GlobalHotKeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "注册全局快捷键失败：\(status)。可能是快捷键已经被其他 App 占用。"
        }
    }
}
