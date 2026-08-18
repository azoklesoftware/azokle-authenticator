//
//  Azokle_AuthApp.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

@main
struct Azokle_AuthApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var vaultManager = VaultManager.shared
    @ObservedObject var prefs = PreferencesStore.shared

    @State private var backgroundTimestamp: Date?

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(.dark)

                // Privacy Shield Overlay when in App Switcher
                if scenePhase != .active && prefs.privacyScreenMask {
                    ZStack {
                        Theme.backgroundDark.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Theme.accentCyan.opacity(0.3), radius: 12)

                            Text("Azokle Auth")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .background {
            if backgroundTimestamp == nil {
                backgroundTimestamp = Date()
            }
            if prefs.autoLockSeconds == 0 {
                vaultManager.lock()
            }
        } else if newPhase == .inactive {
            if oldPhase == .active && backgroundTimestamp == nil {
                backgroundTimestamp = Date()
            }
        } else if newPhase == .active {
            if let bgTime = backgroundTimestamp {
                let elapsed = Date().timeIntervalSince(bgTime)
                if (prefs.autoLockSeconds == 0) || (prefs.autoLockSeconds > 0 && elapsed >= Double(prefs.autoLockSeconds)) {
                    vaultManager.lock()
                }
            }
            backgroundTimestamp = nil
        }
    }
}
