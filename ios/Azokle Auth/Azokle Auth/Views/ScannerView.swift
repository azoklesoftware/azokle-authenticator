//
//  ScannerView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine
import AVFoundation
import PhotosUI

public struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    public let onScanSuccess: ([VaultEntry]) -> Void

    @StateObject private var scannerModel = CameraScannerModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scanErrorMessage: String?

    public init(onScanSuccess: @escaping ([VaultEntry]) -> Void) {
        self.onScanSuccess = onScanSuccess
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                // Camera Preview or Permission Fallback
                if scannerModel.permissionDenied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.accentRed)

                        Text("Camera Access Required")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Please allow camera access in Settings to scan 2FA QR codes, or import an image from your photo library.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open iOS Settings")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.primaryGradient)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.accentCyan)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                } else {
                    CameraPreviewView(session: scannerModel.session)
                        .ignoresSafeArea()

                    // Reticle Overlay
                    VStack {
                        Spacer()

                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.accentCyan, Theme.accentIndigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 260, height: 260)
                                .shadow(color: Theme.accentCyan.opacity(0.5), radius: 16)

                            // Center scan beam line
                            Rectangle()
                                .fill(Theme.accentCyan.opacity(0.8))
                                .frame(width: 240, height: 2)
                                .shadow(color: Theme.accentCyan, radius: 4)
                        }

                        Text("Align QR code within frame")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 24)

                        Spacer()

                        // Bottom Controls (Torch & Gallery)
                        HStack(spacing: 40) {
                            Button(action: scannerModel.toggleTorch) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: scannerModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(scannerModel.isTorchOn ? Theme.accentAmber : .white)
                                }
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }

                if let error = scanErrorMessage {
                    VStack {
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .background(Theme.accentRed.opacity(0.9))
                            .cornerRadius(12)
                            .padding(.top, 60)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Scan 2FA QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        scannerModel.stop()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                scannerModel.onCodeScanned = handleScannedString
                scannerModel.start()
            }
            .onDisappear {
                scannerModel.stop()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
        }
    }

    private func handleScannedString(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Check if Google Authenticator Migration URI
        if trimmed.hasPrefix("otpauth-migration://"), let url = URL(string: trimmed) {
            if let migration = GoogleAuthMigrationParser.parse(url: url) {
                var entries: [VaultEntry] = []
                for item in migration.entries {
                    let secretB32 = Base32.encode(item.secret)
                    let info = OtpInfoModel(secret: secretB32, algo: item.algorithm, digits: item.digits, period: 30, counter: item.counter)
                    entries.append(VaultEntry(type: item.type, name: item.name, issuer: item.issuer, info: info))
                }
                scannerModel.stop()
                onScanSuccess(entries)
                dismiss()
                return
            }
        }

        // 2. Check if standard otpauth:// URI
        if let entry = UniversalImporter.parseSingleOtpauthURI(uriString: trimmed) {
            scannerModel.stop()
            onScanSuccess([entry])
            dismiss()
            return
        }

        scanErrorMessage = "Unsupported QR code format"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            scanErrorMessage = nil
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let ciImage = CIImage(image: uiImage) {

                let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]

                if let codeString = features?.first?.messageString {
                    handleScannedString(codeString)
                } else {
                    scanErrorMessage = "No QR code found in the selected image"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        scanErrorMessage = nil
                    }
                }
            }
        }
    }
}

// MARK: - Camera Preview Wrapper
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Scanner View Model
private final class CameraScannerModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    var onCodeScanned: ((String) -> Void)?
    @Published var isTorchOn: Bool = false
    @Published var permissionDenied: Bool = false

    private var device: AVCaptureDevice?

    override init() {
        super.init()
        checkPermissionsAndSetup()
    }

    private func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                        self?.start()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            permissionDenied = true
            return
        }
        self.device = captureDevice

        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            permissionDenied = true
            return
        }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if self?.session.isRunning == false {
                self?.session.startRunning()
            }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }

    func toggleTorch() {
        guard let device = device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isTorchOn ? .off : .on
            isTorchOn.toggle()
            device.unlockForConfiguration()
        } catch {
            // Torch error
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = object.stringValue else { return }

        onCodeScanned?(stringValue)
    }
}
