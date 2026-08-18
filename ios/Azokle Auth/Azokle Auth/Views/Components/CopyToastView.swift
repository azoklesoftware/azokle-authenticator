//
//  CopyToastView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI

public struct CopyToastView: View {
    public let message: String

    public init(message: String = "Copied to clipboard • Clears in 30s") {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.accentGreen)
                .font(.system(size: 16, weight: .bold))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(hex: "181B26").opacity(0.95))
                .background(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Theme.accentCyan.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 6)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
    }
}
