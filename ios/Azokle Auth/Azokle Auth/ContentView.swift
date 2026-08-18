//
//  ContentView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct ContentView: View {
    @ObservedObject var vaultManager = VaultManager.shared
    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if !hasSeenIntro && !vaultManager.hasExistingVault {
                IntroView {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        hasSeenIntro = true
                    }
                }
                .transition(.opacity)
            } else if vaultManager.isLocked {
                AuthView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                MainVaultView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vaultManager.isLocked)
    }
}

#Preview {
    ContentView()
}
