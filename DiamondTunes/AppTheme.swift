//
//  AppTheme.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/20/26.
//

import SwiftUI

enum AppTheme {

    // 1969 Montreal Expos inspired
    static let background = Color(hex: "#F4F6F8")
    static let surface = Color.white

    static let navy = Color(hex: "#0C2340")
    static let red = Color(hex: "#E4002B")
    static let blue = Color(hex: "#41B6E6")

    static let textPrimary = navy
    static let textSecondary = Color.black.opacity(0.58)

    static let border = Color.black.opacity(0.08)
    static let rowFill = Color.white
    static let success = Color(hex: "#2E8B57")

    static let gameButtonFill = navy
    static let gameButtonText = Color.white

    static let lineupBadgeFill = navy
    static let lineupBadgeText = Color.white

    static let controlRingTrack = Color.black.opacity(0.12)
    static let controlRingProgress = blue
    static let controlIcon = navy
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255,
                ((int >> 8) & 0xF) * 17,
                ((int >> 4) & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (
                255,
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                (int >> 24) & 0xFF,
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
