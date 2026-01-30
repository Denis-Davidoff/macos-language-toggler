//
//  InputSourceManager.swift
//  LanguageToggler
//

import Foundation
import Carbon
import Combine
import AppKit

struct InputSource: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InputSource, rhs: InputSource) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class InputSourceManager: ObservableObject {
    static let shared = InputSourceManager()

    @Published var availableSources: [InputSource] = []
    @Published var currentSource: InputSource?

    private var tisInputSources: [String: TISInputSource] = [:]

    init() {
        loadInputSources()
    }

    func loadInputSources() {
        availableSources.removeAll()
        tisInputSources.removeAll()

        guard let category = kTISCategoryKeyboardInputSource else { return }
        let properties: CFDictionary = [
            kTISPropertyInputSourceCategory as String: category,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary

        guard let sources = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }

        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
                continue
            }

            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String

            let inputSource = InputSource(id: id, name: name)
            availableSources.append(inputSource)
            tisInputSources[id] = source
        }

        updateCurrentSource()
    }

    func updateCurrentSource() {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return
        }

        guard let idPtr = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else {
            return
        }

        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        currentSource = availableSources.first { $0.id == id }
    }

    func selectInputSource(_ source: InputSource, showPopup: Bool = false) {
        guard let tisSource = tisInputSources[source.id] else {
            return
        }

        TISSelectInputSource(tisSource)
        updateCurrentSource()

        if showPopup && UserDefaults.standard.object(forKey: "showLanguagePopup") as? Bool ?? true {
            let code = shortCode(for: source)
            LanguagePopup.shared.show(languageCode: code)
        }
    }

    private func shortCode(for source: InputSource) -> String {
        // Extract short code from input source ID or name
        // ID is like "com.apple.keylayout.Russian" or "com.apple.keylayout.US"
        let knownCodes: [String: String] = [
            "Russian": "RU",
            "US": "EN",
            "ABC": "EN",
            "British": "EN",
            "Ukrainian": "UA",
            "German": "DE",
            "French": "FR",
            "Spanish": "ES",
            "Italian": "IT",
            "Portuguese": "PT",
            "Japanese": "JP",
            "Chinese": "CN",
            "Korean": "KR",
            "Polish": "PL",
            "Czech": "CZ",
            "Turkish": "TR",
            "Arabic": "AR",
            "Hebrew": "HE",
        ]

        // Try to get from the last part of ID
        if let lastPart = source.id.split(separator: ".").last {
            let key = String(lastPart)
            if let code = knownCodes[key] {
                return code
            }
            // Return first 2 chars of the key
            return String(key.prefix(2)).uppercased()
        }

        // Fallback to first 2 chars of name
        return String(source.name.prefix(2)).uppercased()
    }

    func selectInputSource(byId id: String, showPopup: Bool = false) {
        guard let source = availableSources.first(where: { $0.id == id }) else {
            return
        }
        selectInputSource(source, showPopup: showPopup)
    }

    func toggleBetween(_ source1: InputSource, _ source2: InputSource, showPopup: Bool = true) {
        // Get current input source directly from system to avoid stale cache
        let currentId = getCurrentInputSourceId()

        if currentId == source1.id {
            selectInputSource(source2, showPopup: showPopup)
        } else if currentId == source2.id {
            selectInputSource(source1, showPopup: showPopup)
        } else {
            // If current language is neither of the two, switch to source1
            selectInputSource(source1, showPopup: showPopup)
        }
    }

    private func getCurrentInputSourceId() -> String? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let idPtr = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }
}
