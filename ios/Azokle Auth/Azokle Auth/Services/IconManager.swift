//
//  IconManager.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct BrandSuggestion: Identifiable {
    public let id = UUID()
    public let name: String
    public let sfSymbol: String
    public let colors: [Color]
}

public final class IconManager: ObservableObject {
    public static let shared = IconManager()

    private let iconsDirectory: URL

    public static let brands: [BrandSuggestion] = [
        BrandSuggestion(name: "Google", sfSymbol: "g.circle.fill", colors: [Color(hex: "4285F4"), Color(hex: "EA4335")]),
        BrandSuggestion(name: "GitHub", sfSymbol: "chevron.left.forwardslash.chevron.right", colors: [Color(hex: "24292E"), Color(hex: "586069")]),
        BrandSuggestion(name: "Microsoft", sfSymbol: "square.grid.2x2.fill", colors: [Color(hex: "00A4EF"), Color(hex: "7FBA00")]),
        BrandSuggestion(name: "Apple", sfSymbol: "apple.logo", colors: [Color(hex: "A2AAAD"), Color(hex: "636366")]),
        BrandSuggestion(name: "Discord", sfSymbol: "bubble.left.and.bubble.right.fill", colors: [Color(hex: "5865F2"), Color(hex: "7983F5")]),
        BrandSuggestion(name: "Steam", sfSymbol: "gamecontroller.fill", colors: [Color(hex: "171A21"), Color(hex: "1B2838")]),
        BrandSuggestion(name: "Amazon", sfSymbol: "cart.fill", colors: [Color(hex: "FF9900"), Color(hex: "146EB4")]),
        BrandSuggestion(name: "Twitter / X", sfSymbol: "xmark", colors: [Color(hex: "1DA1F2"), Color(hex: "000000")]),
        BrandSuggestion(name: "Cloudflare", sfSymbol: "cloud.sun.fill", colors: [Color(hex: "F38020"), Color(hex: "FAAE40")]),
        BrandSuggestion(name: "Binance", sfSymbol: "bitcoinsign.circle.fill", colors: [Color(hex: "F0B90B"), Color(hex: "FCD535")]),
        BrandSuggestion(name: "Reddit", sfSymbol: "person.2.circle.fill", colors: [Color(hex: "FF4500"), Color(hex: "FF5700")]),
        BrandSuggestion(name: "Slack", sfSymbol: "number", colors: [Color(hex: "4A154B"), Color(hex: "E01E5A")]),
        BrandSuggestion(name: "Dropbox", sfSymbol: "archivebox.fill", colors: [Color(hex: "0061FF"), Color(hex: "3984FF")]),
        BrandSuggestion(name: "GitLab", sfSymbol: "flame.fill", colors: [Color(hex: "FC6D26"), Color(hex: "E24329")]),
        BrandSuggestion(name: "Bitwarden", sfSymbol: "shield.lefthalf.filled", colors: [Color(hex: "175DDC"), Color(hex: "2970FF")]),
        BrandSuggestion(name: "Proton", sfSymbol: "envelope.badge.shield.half.filled", colors: [Color(hex: "6D4AFF"), Color(hex: "8B6FFF")])
    ]

    private init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        iconsDirectory = paths[0].appendingPathComponent("Icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: iconsDirectory, withIntermediateDirectories: true)
    }

    public static func matchBrand(for text: String) -> BrandSuggestion? {
        let clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        for brand in brands {
            if clean.contains(brand.name.lowercased()) || brand.name.lowercased().contains(clean) {
                return brand
            }
        }
        return nil
    }

    public func saveCustomIcon(id: UUID, image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        let filename = "\(id.uuidString).png"
        let fileURL = iconsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            return filename
        } catch {
            return nil
        }
    }

    public func loadCustomIcon(filename: String) -> UIImage? {
        let fileURL = iconsDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    public func deleteCustomIcon(filename: String) {
        let fileURL = iconsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
