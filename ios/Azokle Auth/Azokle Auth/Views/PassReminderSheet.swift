//
//  PassReminderSheet.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI

public struct PassReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onSuccess: () -> Void

    @State private var password = ""
    @State private var errorMessage: String?
    @State private var shakeOffset: CGFloat = 0

    public init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Theme.accentCyan.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.accentCyan)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 8) {
                        Text("Password Health Check")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("To protect against forgotten master passwords, please enter your password to confirm.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Password Field
                    VStack(spacing: 16) {
                        SecureField("Master Password", text: $password)
                            .textContentType(.password)
                            .padding(14)
                            .background(Color(hex: "12141C"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "1E2336"), lineWidth: 1)
                            )
                            .foregroundColor(.white)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.accentRed)
                        }

                        Button(action: handleVerify) {
                            Text("Verify Password")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.primaryGradient)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        .disabled(password.isEmpty)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 18)
                    .offset(x: shakeOffset)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Password Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private func handleVerify() {
        if PassReminderService.shared.verify(password: password) {
            Theme.triggerNotificationHaptic(type: .success)
            onSuccess()
            dismiss()
        } else {
            errorMessage = "Incorrect master password. Please try again."
            Theme.triggerNotificationHaptic(type: .error)
            withAnimation(.default) { shakeOffset = -10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.default) { shakeOffset = 10 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.default) { shakeOffset = 0 }
            }
        }
    }
}
