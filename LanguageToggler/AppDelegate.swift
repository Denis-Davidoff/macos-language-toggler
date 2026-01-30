//
//  AppDelegate.swift
//  LanguageToggler
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        if let bundleId = Bundle.main.bundleIdentifier {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if runningApps.count > 1 {
                // Another instance is running, quit this one
                NSApp.terminate(nil)
                return
            }
        }

        setupStatusBar()
        checkAndRequestAccessibility()
        HotkeyManager.shared.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stopListening()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Language Toggler")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: String(localized: "About LanguageToggler"), action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = String(localized: "Settings")
            settingsWindow?.styleMask = [.titled, .closable]
            settingsWindow?.center()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            let aboutView = AboutView()
            let hostingController = NSHostingController(rootView: aboutView)

            aboutWindow = NSWindow(contentViewController: hostingController)
            aboutWindow?.title = String(localized: "About LanguageToggler")
            aboutWindow?.styleMask = [.titled, .closable]
            aboutWindow?.center()
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func checkAndRequestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("Accessibility access not granted. Global hotkeys will not work.")
        }
    }
}
