//
//  SettingsView.swift
//  LanguageToggler
//

import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var inputManager = InputSourceManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared

    @State private var selectedToggleLang1: String = ""
    @State private var selectedToggleLang2: String = ""
    @State private var recordingFor: RecordingTarget?
    @State private var showingAccessibilityAlert = false
    @State private var hasAccessibility = false
    @State private var localMonitor: Any?
    @State private var launchAtLogin = false
    @AppStorage("showLanguagePopup") private var showLanguagePopup = true
    @AppStorage("appLanguage") private var appLanguage = "auto"
    @State private var initialLanguage = ""

    private let labelWidth: CGFloat = 120

    private let availableLanguages: [(code: String, name: String)] = [
        ("auto", "Automatic"),
        ("en", "English"),
        ("es", "Español"),
        ("ru", "Русский"),
        ("uk", "Українська"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("it", "Italiano"),
        ("tr", "Türkçe"),
        ("zh-Hans", "中文"),
        ("ja", "日本語")
    ]

    enum RecordingTarget: Equatable {
        case toggle
        case language(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Toggle section
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Language 1:")
                            .frame(width: labelWidth, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedToggleLang1) {
                            Text("Not selected").tag("")
                            ForEach(inputManager.availableSources) { source in
                                Text(source.name).tag(source.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GridRow {
                        Text("Language 2:")
                            .frame(width: labelWidth, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedToggleLang2) {
                            Text("Not selected").tag("")
                            ForEach(inputManager.availableSources) { source in
                                Text(source.name).tag(source.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GridRow {
                        Text("Hotkey:")
                            .frame(width: labelWidth, alignment: .trailing)
                            .foregroundColor(.secondary)
                        HotkeyRecorderButton(
                            hotkey: hotkeyManager.toggleHotkey,
                            isRecording: recordingFor == .toggle,
                            onStartRecording: {
                                startRecording(for: .toggle)
                            },
                            onClear: {
                                hotkeyManager.setToggleHotkey(nil)
                            }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
            } label: {
                Text("Toggle between two languages")
                    .fontWeight(.semibold)
            }

            // Per-language hotkeys
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    ForEach(inputManager.availableSources) { source in
                        GridRow {
                            Text(source.name)
                                .frame(width: labelWidth, alignment: .trailing)
                                .foregroundColor(.secondary)
                            HotkeyRecorderButton(
                                hotkey: hotkeyManager.languageHotkeys[source.id],
                                isRecording: recordingFor == .language(source.id),
                                onStartRecording: {
                                    startRecording(for: .language(source.id))
                                },
                                onClear: {
                                    hotkeyManager.setLanguageHotkey(nil, for: source.id)
                                }
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 8)
            } label: {
                Text("Hotkeys for individual languages")
                    .fontWeight(.semibold)
            }

            Spacer()

            Divider()

            // Bottom settings
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                Toggle("Show language indicator", isOn: $showLanguagePopup)

                HStack {
                    Text("Interface language:")
                    Picker("", selection: $appLanguage) {
                        ForEach(availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .onChange(of: appLanguage) { _, newValue in
                        setAppLanguage(newValue)
                    }
                }
            }

            HStack {
                if !hasAccessibility {
                    Button("Grant Accessibility Access") {
                        requestAccessibilityPermissions()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 10)
        .frame(width: 440, height: 540)
        .onAppear {
            selectedToggleLang1 = hotkeyManager.toggleLanguage1 ?? ""
            selectedToggleLang2 = hotkeyManager.toggleLanguage2 ?? ""
            initialLanguage = appLanguage
            checkAccessibility()
            checkLaunchAtLogin()
        }
        .onDisappear {
            stopLocalMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window.title == String(localized: "Settings") else { return }
            if initialLanguage != appLanguage && !initialLanguage.isEmpty {
                restartApp()
            }
        }
        .onChange(of: selectedToggleLang1) { _, newValue in
            hotkeyManager.setToggleLanguages(
                lang1: newValue.isEmpty ? nil : newValue,
                lang2: selectedToggleLang2.isEmpty ? nil : selectedToggleLang2
            )
        }
        .onChange(of: selectedToggleLang2) { _, newValue in
            hotkeyManager.setToggleLanguages(
                lang1: selectedToggleLang1.isEmpty ? nil : selectedToggleLang1,
                lang2: newValue.isEmpty ? nil : newValue
            )
        }
        .alert("Accessibility Access", isPresented: $showingAccessibilityAlert) {
            Button("Open Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Global hotkeys require Accessibility access. Please enable it in System Settings → Privacy & Security → Accessibility")
        }
    }

    private func checkAccessibility() {
        hasAccessibility = AXIsProcessTrusted()
    }

    private func checkLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setAppLanguage(_ language: String) {
        if language == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    private func restartApp() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]

        do {
            try task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } catch {
            print("Failed to restart: \(error)")
        }
    }

    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibility = trusted

        if !trusted {
            showingAccessibilityAlert = true
        }
    }

    private func startRecording(for target: RecordingTarget) {
        recordingFor = target

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = UInt32(event.keyCode)
            var modifiers: UInt32 = 0

            if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
            if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
            if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }

            let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)

            DispatchQueue.main.async {
                switch target {
                case .toggle:
                    self.hotkeyManager.setToggleHotkey(hotkey)
                case .language(let id):
                    self.hotkeyManager.setLanguageHotkey(hotkey, for: id)
                }
                self.recordingFor = nil
                self.stopLocalMonitor()
            }

            return nil
        }
    }

    private func stopLocalMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

struct HotkeyRecorderButton: View {
    let hotkey: Hotkey?
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onStartRecording) {
                Text(isRecording ? "Press keys..." : (hotkey?.displayString ?? "Not set"))
                    .frame(width: 140)
                    .foregroundColor(hotkey == nil && !isRecording ? .secondary : .primary)
            }
            .buttonStyle(.bordered)

            if hotkey != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove hotkey")
            }
        }
    }
}

#Preview {
    SettingsView()
}
