//
//  VaultTheme.swift
//  vaultd
//
//  Brand colors and shared styling.
//

import SwiftUI

extension Color {
    /// #ff7f00 — Vaultd signature orange
    static let vaultOrange = Color(red: 1.0, green: 0.498, blue: 0.0)
    /// #1a1c1c — near-black background
    static let vaultDark   = Color(red: 0.102, green: 0.110, blue: 0.110)
    /// #fff5eb — warm off-white tint
    static let vaultWarm   = Color(red: 1.0, green: 0.961, blue: 0.922)
}

// MARK: - Shared button style

struct VaultPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.vaultOrange.opacity(configuration.isPressed ? 0.75 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == VaultPrimaryButtonStyle {
    static var vaultPrimary: VaultPrimaryButtonStyle { .init() }
}
