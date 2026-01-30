//
//  HotkeyManager.swift
//  LanguageToggler
//

import Foundation
import Carbon
import AppKit
import Combine

struct Hotkey: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
            51: "Delete", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
            120: "F1", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode]
    }
}

@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @Published var toggleHotkey: Hotkey?
    @Published var languageHotkeys: [String: Hotkey] = [:]
    @Published var toggleLanguage1: String?
    @Published var toggleLanguage2: String?

    var isRecording = false
    var recordingCallback: ((Hotkey) -> Void)?

    init() {
        loadSettings()
    }

    func startListening() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEventSync(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("Failed to create event tap. Check Accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopListening() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }

    nonisolated private func handleEventSync(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        var modifiers: UInt32 = 0

        if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }

        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)

        let result = MainActor.assumeIsolated {
            return self.processHotkey(hotkey)
        }

        if result {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func processHotkey(_ hotkey: Hotkey) -> Bool {
        if isRecording {
            recordingCallback?(hotkey)
            isRecording = false
            recordingCallback = nil
            return true
        }

        if let toggleHotkey = toggleHotkey, toggleHotkey == hotkey {
            performToggle()
            return true
        }

        for (languageId, langHotkey) in languageHotkeys {
            if langHotkey == hotkey {
                InputSourceManager.shared.selectInputSource(byId: languageId, showPopup: true)
                return true
            }
        }

        return false
    }

    private func performToggle() {
        guard let lang1 = toggleLanguage1,
              let lang2 = toggleLanguage2,
              let source1 = InputSourceManager.shared.availableSources.first(where: { $0.id == lang1 }),
              let source2 = InputSourceManager.shared.availableSources.first(where: { $0.id == lang2 }) else {
            return
        }

        InputSourceManager.shared.toggleBetween(source1, source2)
    }

    func startRecording(completion: @escaping (Hotkey) -> Void) {
        isRecording = true
        recordingCallback = completion
    }

    func cancelRecording() {
        isRecording = false
        recordingCallback = nil
    }

    func setToggleHotkey(_ hotkey: Hotkey?) {
        toggleHotkey = hotkey
        saveSettings()
    }

    func setLanguageHotkey(_ hotkey: Hotkey?, for languageId: String) {
        if let hotkey = hotkey {
            languageHotkeys[languageId] = hotkey
        } else {
            languageHotkeys.removeValue(forKey: languageId)
        }
        saveSettings()
    }

    func setToggleLanguages(lang1: String?, lang2: String?) {
        toggleLanguage1 = lang1
        toggleLanguage2 = lang2
        saveSettings()
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard

        if let toggleHotkey = toggleHotkey,
           let data = try? JSONEncoder().encode(toggleHotkey) {
            defaults.set(data, forKey: "toggleHotkey")
        } else {
            defaults.removeObject(forKey: "toggleHotkey")
        }

        if let data = try? JSONEncoder().encode(languageHotkeys) {
            defaults.set(data, forKey: "languageHotkeys")
        }

        defaults.set(toggleLanguage1, forKey: "toggleLanguage1")
        defaults.set(toggleLanguage2, forKey: "toggleLanguage2")
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: "toggleHotkey"),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            toggleHotkey = hotkey
        }

        if let data = defaults.data(forKey: "languageHotkeys"),
           let hotkeys = try? JSONDecoder().decode([String: Hotkey].self, from: data) {
            languageHotkeys = hotkeys
        }

        toggleLanguage1 = defaults.string(forKey: "toggleLanguage1")
        toggleLanguage2 = defaults.string(forKey: "toggleLanguage2")
    }
}
