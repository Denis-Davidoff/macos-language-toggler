//
//  LanguagePopup.swift
//  LanguageToggler
//

import AppKit
import SwiftUI

class LanguagePopup {
    static let shared = LanguagePopup()

    private var window: NSWindow?
    private var hideTask: Task<Void, Never>?

    func show(languageCode: String) {
        hideTask?.cancel()

        // Create or update window
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            window = panel
        }

        guard let window = window else { return }

        // Create content view with intrinsic size
        let popupView = PopupView(languageCode: languageCode)
        let hostingView = NSHostingView(rootView: popupView)
        let size = hostingView.fittingSize
        hostingView.setFrameSize(size)
        window.contentView = hostingView
        window.setContentSize(size)

        // Position at center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.midY - size.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show
        window.orderFrontRegardless()

        // Hide after delay
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            if !Task.isCancelled {
                self.window?.orderOut(nil)
            }
        }
    }
}

struct PopupView: View {
    let languageCode: String

    var body: some View {
        Text(languageCode.uppercased())
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(.white.opacity(0.75))
            .fixedSize()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.black.opacity(0.25))
            )
    }
}
