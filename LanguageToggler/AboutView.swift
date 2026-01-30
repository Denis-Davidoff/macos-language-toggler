//
//  AboutView.swift
//  LanguageToggler
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("LanguageToggler")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("Author: Denis Davydov")
                Text("License: MIT - Free for everyone")
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            Text("Made with Claude AI")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()

            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 20)
        }
        .padding(30)
        .frame(width: 300, height: 340)
    }
}

#Preview {
    AboutView()
}
