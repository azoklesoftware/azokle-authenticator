//
//  AuthView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct AuthView: View {
    @ObservedObject var vaultManager = VaultManager.shared

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isCreatingVault = false
    @State private var isLoading = false
    @State private var shakeOffset: CGFloat = 0

    public init() {}

    public var body: some View {
        ZStack {
            Theme.backgroundDark.ignoresSafeArea()

            // Background subtle gradient orbs
            GeometryReader { proxy in
                Circle()
                    .fill(Theme.accentBlue.opacity(0.15))
                    .blur(radius: 80)
                    .frame(width: 300, height: 300)
                    .offset(x: -50, y: -50)

                Circle()
                    .fill(Theme.accentIndigo.opacity(0.15))
                    .blur(radius: 90)
                    .frame(width: 350, height: 350)
                    .offset(x: proxy.size.width - 200, y: proxy.size.height - 300)
            }

            VStack(spacing: 32) {
                Spacer()

                // Brand Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.primaryGradient)
                            .frame(width: 88, height: 88)
                            .shadow(color: Theme.accentBlue.opacity(0.4), radius: 20, x: 0, y: 10)

                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text("Azokle Auth")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(vaultManager.hasExistingVault ? "Unlock your secure 2FA vault" : "Create a new encrypted vault")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Input Card
                VStack(spacing: 20) {
                    if !vaultManager.hasExistingVault {
                        // Setup Mode
                        SecureField("Master Password", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        Button(action: handleCreateVault) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Vault")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.primaryGradient)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .shadow(color: Theme.accentBlue.opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(password.isEmpty || confirmPassword.isEmpty || isLoading)

                    } else {
                        // Unlock Mode
                        HStack {
                            SecureField("Enter Master Password", text: $password)
                                .textContentType(.password)
                                .onSubmit(handleUnlock)
                                .foregroundColor(.white)

                            if !password.isEmpty {
                                Button(action: handleUnlock) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(Theme.accentCyan)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)

                        Button(action: handleUnlock) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Unlock Vault")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.primaryGradient)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .shadow(color: Theme.accentBlue.opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(password.isEmpty || isLoading)

                        // Face ID / Touch ID button
                        if vaultManager.isBiometricsConfigured {
                            Button(action: handleBiometrics) {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 20))
                                    Text("Unlock with Face ID / Touch ID")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(Theme.accentCyan)
                                .padding(.top, 4)
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.accentRed)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(24)
                .glassCard(cornerRadius: 24)
                .offset(x: shakeOffset)
                .padding(.horizontal, 24)

                Spacer()

                // Offline badge footer
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(Theme.accentGreen)
                    Text("100% Offline • Zero Telemetry")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if vaultManager.hasExistingVault && vaultManager.isBiometricsConfigured {
                handleBiometrics()
            }
        }
    }

    private func handleCreateVault() {
        guard password == confirmPassword else {
            triggerShake(error: "Passwords do not match")
            return
        }
        guard password.count >= 6 else {
            triggerShake(error: "Password must be at least 6 characters")
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await vaultManager.createVault(password: password)
                isLoading = false
            } catch {
                isLoading = false
                triggerShake(error: error.localizedDescription)
            }
        }
    }

    private func handleUnlock() {
        guard !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await vaultManager.unlock(password: password)
                isLoading = false
            } catch {
                isLoading = false
                triggerShake(error: "Incorrect password")
            }
        }
    }

    private func handleBiometrics() {
        Task {
            do {
                try await vaultManager.unlockWithBiometrics()
            } catch {
                // Biometrics cancelled or failed; fallback to password
            }
        }
    }

    private func triggerShake(error: String) {
        errorMessage = error
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        withAnimation(.default) {
            shakeOffset = -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) { shakeOffset = 12 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) { shakeOffset = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}
