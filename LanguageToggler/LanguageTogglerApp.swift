//
//  LanguageTogglerApp.swift
//  LanguageToggler
//

import SwiftUI

@main
struct LanguageTogglerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
