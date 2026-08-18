//
//  EntryCardView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct EntryCardView: View {
    public let entry: VaultEntry
    public let progress: TOTPProgress
    public let viewMode: ViewMode
    public let onCopy: () -> Void
    public let onEdit: () -> Void
    public let onToggleFavorite: () -> Void
    public let onDelete: () -> Void
    public let onIncrementCounter: () -> Void

    @ObservedObject var prefs = PreferencesStore.shared
    @State private var isRevealed: Bool = false
    @State private var justCopied: Bool = false

    public init(
        entry: VaultEntry,
        progress: TOTPProgress,
        viewMode: ViewMode = .normal,
        onCopy: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onIncrementCounter: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.progress = progress
        self.viewMode = viewMode
        self.onCopy = onCopy
        self.onEdit = onEdit
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
        self.onIncrementCounter = onIncrementCounter
    }

    public var body: some View {
        Button(action: handleCardTap) {
            switch viewMode {
            case .normal:
                normalCardLayout
            case .compact:
                compactCardLayout
            case .small:
                smallCardLayout
            case .tiles:
                tileCardLayout
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: handleCopy) {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            if entry.type == .totp {
                Button(action: handleCopyNextCode) {
                    Label("Copy Next Code", systemImage: "clock.arrow.2.circlepath")
                }
            }
            Button(action: onToggleFavorite) {
                Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "star.slash" : "star.fill")
            }
            Button(action: onEdit) {
                Label("Edit Entry", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleFavorite()
                Theme.triggerHaptic(style: .light)
            } label: {
                Label("Favorite", systemImage: entry.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(Theme.favoriteGold)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
                Theme.triggerNotificationHaptic(type: .warning)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Theme.accentIndigo)
        }
    }

    // MARK: - Normal View Layout
    private var normalCardLayout: some View {
        HStack(spacing: 16) {
            // Icon Monogram
            iconMonogram

            // Issuer, Name & OTP
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.issuer.isEmpty ? "Token" : entry.issuer)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.favoriteGold)
                    }

                    if entry.type != .totp {
                        Text(entry.type.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accentIndigo.opacity(0.3))
                            .cornerRadius(4)
                            .foregroundColor(Theme.accentCyan)
                    }
                }

                if !entry.name.isEmpty {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }

                // OTP Display
                HStack(spacing: 10) {
                    if prefs.tapToReveal && !isRevealed {
                        Text("••••••")
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.accentCyan.opacity(0.6))
                    } else {
                        Text(Theme.formatCode(progress.code, grouping: prefs.codeGrouping))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(justCopied ? Theme.accentGreen : Theme.accentCyan)
                            .monospacedDigit()
                    }

                    if justCopied {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.accentGreen)
                            .font(.system(size: 18))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // Timer Ring or HOTP Counter Trigger
            if entry.type == .hotp {
                Button(action: onIncrementCounter) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentIndigo.opacity(0.25))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.accentCyan)
                    }
                }
            } else {
                DynamicTimerRing(progress: progress, size: 36, lineWidth: 3.5, showSeconds: true)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18, isHighlighted: entry.isFavorite)
    }

    // MARK: - Compact View Layout
    private var compactCardLayout: some View {
        HStack(spacing: 12) {
            smallMonogram

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.issuer.isEmpty ? entry.name : entry.issuer)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.favoriteGold)
                    }
                }

                if !entry.name.isEmpty && !entry.issuer.isEmpty {
                    Text(entry.name)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(prefs.tapToReveal && !isRevealed ? "••••••" : Theme.formatCode(progress.code, grouping: prefs.codeGrouping))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(justCopied ? Theme.accentGreen : Theme.accentCyan)
                .monospacedDigit()

            if entry.type != .hotp {
                DynamicTimerRing(progress: progress, size: 22, lineWidth: 2.5, showSeconds: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14, isHighlighted: entry.isFavorite)
    }

    // MARK: - Small View Layout
    private var smallCardLayout: some View {
        HStack {
            HStack(spacing: 6) {
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.favoriteGold)
                }

                Text(entry.issuer.isEmpty ? entry.name : entry.issuer)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Text(prefs.tapToReveal && !isRevealed ? "••••••" : Theme.formatCode(progress.code, grouping: prefs.codeGrouping))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(justCopied ? Theme.accentGreen : Theme.accentCyan)
                .monospacedDigit()

            if entry.type != .hotp {
                Text("\(progress.remainingSeconds)s")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.timerColor(remainingSeconds: progress.remainingSeconds, totalPeriod: progress.period))
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 10, isHighlighted: entry.isFavorite)
    }

    // MARK: - Tile Grid Layout
    private var tileCardLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                smallMonogram
                Spacer()
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.favoriteGold)
                }
                if entry.type != .hotp {
                    DynamicTimerRing(progress: progress, size: 24, lineWidth: 2.5, showSeconds: true)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.issuer.isEmpty ? "Token" : entry.issuer)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !entry.name.isEmpty {
                    Text(entry.name)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Text(prefs.tapToReveal && !isRevealed ? "••••••" : Theme.formatCode(progress.code, grouping: prefs.codeGrouping))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(justCopied ? Theme.accentGreen : Theme.accentCyan)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .glassCard(cornerRadius: 16, isHighlighted: entry.isFavorite)
    }

    // MARK: - Monogram & Brand Icon Helpers
    private var iconMonogram: some View {
        ZStack {
            if let iconName = entry.icon, let uiImage = IconManager.shared.loadCustomIcon(filename: iconName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let brand = IconManager.matchBrand(for: entry.issuer.isEmpty ? entry.name : entry.issuer) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: brand.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)

                Image(systemName: brand.sfSymbol)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentBlue.opacity(0.35), Theme.accentIndigo.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(monogramLetter)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private var smallMonogram: some View {
        ZStack {
            if let iconName = entry.icon, let uiImage = IconManager.shared.loadCustomIcon(filename: iconName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let brand = IconManager.matchBrand(for: entry.issuer.isEmpty ? entry.name : entry.issuer) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: brand.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)

                Image(systemName: brand.sfSymbol)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentBlue.opacity(0.35), Theme.accentIndigo.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text(monogramLetter)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private var monogramLetter: String {
        let name = entry.issuer.isEmpty ? entry.name : entry.issuer
        return String(name.prefix(1)).uppercased()
    }

    // MARK: - Actions
    private func handleCardTap() {
        if prefs.tapToReveal && !isRevealed {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isRevealed = true
            }
            Theme.triggerHaptic(style: .light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation { isRevealed = false }
            }
            return
        }

        handleCopy()
    }

    private func handleCopy() {
        ClipboardService.shared.copy(code: progress.code)
        onCopy()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            justCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { justCopied = false }
        }
    }

    private func handleCopyNextCode() {
        guard let nextCode = entry.nextCode(timestamp: Date().timeIntervalSince1970) else { return }
        ClipboardService.shared.copy(code: nextCode)
        Theme.triggerNotificationHaptic(type: .success)
    }
}
