//
//  TransferView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine

public struct TransferView: View {
    @Environment(\.dismiss) private var dismiss
    public let entries: [VaultEntry]

    @State private var currentFrameIndex = 0
    @State private var isAutoPlaying = true
    @State private var qrFrames: [String] = []

    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    public init(entries: [VaultEntry]) {
        self.entries = entries
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header Description
                    VStack(spacing: 6) {
                        Text("Transfer Tokens Offline")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Scan these QR codes with Azokle Auth on your other device.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 10)

                    Spacer()

                    // QR Code Card
                    if !qrFrames.isEmpty {
                        let currentPayload = qrFrames[currentFrameIndex]
                        VStack(spacing: 16) {
                            if let qrImage = generateQRCode(from: currentPayload) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 250, height: 250)
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: Theme.accentCyan.opacity(0.3), radius: 15)
                            }

                            // Progress Indicator
                            HStack(spacing: 8) {
                                Text("Frame \(currentFrameIndex + 1) of \(qrFrames.count)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.accentCyan)

                                if qrFrames.count > 1 {
                                    Button {
                                        isAutoPlaying.toggle()
                                    } label: {
                                        Image(systemName: isAutoPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Frame Carousel Controls
                    if qrFrames.count > 1 {
                        HStack(spacing: 20) {
                            Button {
                                Theme.triggerHaptic(style: .light)
                                if currentFrameIndex > 0 {
                                    currentFrameIndex -= 1
                                } else {
                                    currentFrameIndex = qrFrames.count - 1
                                }
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "12141C"))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                            }

                            Button {
                                Theme.triggerHaptic(style: .light)
                                if currentFrameIndex < qrFrames.count - 1 {
                                    currentFrameIndex += 1
                                } else {
                                    currentFrameIndex = 0
                                }
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Theme.primaryGradient)
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Done Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Device Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                generateFrames()
            }
            .onReceive(timer) { _ in
                guard isAutoPlaying && qrFrames.count > 1 else { return }
                withAnimation {
                    currentFrameIndex = (currentFrameIndex + 1) % qrFrames.count
                }
            }
        }
    }

    private func generateFrames() {
        // Chunk entries into batches of 8 for maximum QR code scannability
        let chunkSize = 8
        var frames: [String] = []

        let chunks = stride(from: 0, to: entries.count, by: chunkSize).map {
            Array(entries[$0..<min($0 + chunkSize, entries.count)])
        }

        for chunk in chunks {
            if let uri = GoogleAuthMigrationParser.encodePayload(entries: chunk) {
                frames.append(uri)
            } else {
                // Fallback to single otpauth:// URIs
                for entry in chunk {
                    frames.append(entry.otpauthUri)
                }
            }
        }

        self.qrFrames = frames.isEmpty ? ["otpauth://totp/Azokle:Demo?secret=JBSWY3DPEHPK3PXP"] : frames
    }

    private static let ciContext = CIContext()

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        if let cgImage = Self.ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
