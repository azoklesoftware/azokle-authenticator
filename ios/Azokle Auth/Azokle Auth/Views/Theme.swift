//
//  Theme.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct Theme {
    // Primary Brand Gradients
    public static let primaryGradient = LinearGradient(
        colors: [Color(hex: "06B6D4"), Color(hex: "6366F1")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let accentGradient = LinearGradient(
        colors: [Color(hex: "38BDF8"), Color(hex: "818CF8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Palette Tokens (Mirroring Android Material 3 & AMOLED Black)
    public static let accentCyan = Color(hex: "06B6D4")
    public static let accentBlue = Color(hex: "0EA5E9")
    public static let accentIndigo = Color(hex: "6366F1")
    public static let accentGreen = Color(hex: "10B981")
    public static let accentAmber = Color(hex: "F59E0B")
    public static let accentRed = Color(hex: "EF4444")
    public static let favoriteGold = Color(hex: "F9A825")

    // Surfaces
    public static let backgroundDark = Color(hex: "000000") // Pure AMOLED Black
    public static let surfaceContainer = Color(hex: "0D0E11")
    public static let cardBackground = Color(hex: "12141C")
    public static let cardBackgroundHighlighted = Color(hex: "181B26")
    public static let cardBorder = Color(hex: "1E2336")

    // Text & Subdued
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.7)
    public static let textTertiary = Color.white.opacity(0.45)

    // Dynamic Timer Ring & Bar Color
    public static func timerColor(remainingSeconds: Int, totalPeriod: Int) -> Color {
        let ratio = Double(remainingSeconds) / Double(max(1, totalPeriod))
        if ratio > 0.33 {
            return accentCyan
        } else if ratio > 0.16 {
            return accentAmber
        } else {
            return accentRed
        }
    }

    // Code Grouping Formatter
    public static func formatCode(_ code: String, grouping: CodeGrouping) -> String {
        let clean = code.replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return "" }

        switch grouping {
        case .none:
            return clean
        case .half:
            let mid = clean.count / 2
            let first = clean.prefix(mid)
            let second = clean.suffix(clean.count - mid)
            return "\(first) \(second)"
        case .pairs:
            var result = ""
            for (idx, char) in clean.enumerated() {
                if idx > 0 && idx % 2 == 0 {
                    result.append(" ")
                }
                result.append(char)
            }
            return result
        }
    }

    // System Haptic Feedback Triggers
    public static func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func triggerNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Color Hex Extension
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
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

// MARK: - Glassmorphic Card View Modifier
public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isHighlighted: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHighlighted ? Theme.cardBackgroundHighlighted : Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighlighted
                            ? LinearGradient(
                                colors: [Theme.accentCyan.opacity(0.6), Theme.accentIndigo.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Theme.cardBorder, Theme.cardBorder.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 16, isHighlighted: Bool = false) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
