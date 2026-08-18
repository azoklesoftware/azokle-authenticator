//
//  IntroView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI

public struct IntroView: View {
    public let onGetStarted: () -> Void
    @State private var currentSlide = 0

    private struct SlideItem: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let iconName: String
        let gradient: LinearGradient
    }

    private let slides = [
        SlideItem(
            title: "Welcome to Azokle Auth",
            description: "A fast, open, and secure multi-factor authentication manager built with zero compromise on privacy.",
            iconName: "shield.lefthalf.filled.badge.checkmark",
            gradient: LinearGradient(colors: [Theme.accentCyan, Theme.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        SlideItem(
            title: "100% Offline & Zero Telemetry",
            description: "No network tracking, analytics, or remote servers. All your cryptographic keys remain strictly on your device.",
            iconName: "network.slash",
            gradient: LinearGradient(colors: [Theme.accentIndigo, Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        SlideItem(
            title: "Hardware-Backed Encryption",
            description: "Encrypted with AES-256-GCM and hardened by scrypt (N=32768) with instant Face ID and Touch ID unlocking.",
            iconName: "lock.shield.fill",
            gradient: LinearGradient(colors: [Theme.accentCyan, Theme.accentIndigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    public init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
    }

    public var body: some View {
        ZStack {
            Theme.backgroundDark.ignoresSafeArea()

            VStack(spacing: 32) {
                // Top App Badge
                HStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Azokle Auth")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 24)

                Spacer()

                // Slide Content
                TabView(selection: $currentSlide) {
                    ForEach(0..<slides.count, id: \.self) { idx in
                        let slide = slides[idx]
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(slide.gradient.opacity(0.15))
                                    .frame(width: 130, height: 130)

                                Circle()
                                    .stroke(slide.gradient.opacity(0.4), lineWidth: 2)
                                    .frame(width: 130, height: 130)

                                Image(systemName: slide.iconName)
                                    .font(.system(size: 54))
                                    .foregroundStyle(slide.gradient)
                            }
                            .shadow(color: Theme.accentCyan.opacity(0.3), radius: 20)

                            VStack(spacing: 12) {
                                Text(slide.title)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text(slide.description)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 380)

                Spacer()

                // Bottom Action Button
                VStack(spacing: 16) {
                    Button {
                        Theme.triggerHaptic(style: .medium)
                        if currentSlide < slides.count - 1 {
                            withAnimation(.easeInOut) { currentSlide += 1 }
                        } else {
                            onGetStarted()
                        }
                    } label: {
                        HStack {
                            Text(currentSlide == slides.count - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Theme.accentCyan.opacity(0.4), radius: 12, y: 6)
                    }
                    .padding(.horizontal, 24)

                    if currentSlide < slides.count - 1 {
                        Button("Skip") {
                            onGetStarted()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}
