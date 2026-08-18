//
//  SettingsView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultManager = VaultManager.shared
    @ObservedObject var prefs = PreferencesStore.shared
    @ObservedObject var auditLog = AuditLogService.shared

    @State private var showingChangePasswordSheet = false
    @State private var showingBackupPasswordSheet = false
    @State private var showingFileImporter = false
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showingWipeAlert = false
    @State private var statusMessage: String?
    @State private var showingImportPasswordPrompt = false
    @State private var pendingImportData: Data?
    @State private var pendingImportFilename: String = ""
    @State private var importPasswordInput = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                Form {
                    // MARK: - Security & Biometrics
                    Section("Security & Authentication") {
                        if vaultManager.isBiometricsAvailable {
                            Toggle("Face ID / Touch ID", isOn: Binding(
                                get: { vaultManager.isBiometricsConfigured },
                                set: { enabled in
                                    if enabled {
                                        try? vaultManager.enableBiometrics()
                                    } else {
                                        try? vaultManager.disableBiometrics()
                                    }
                                }
                            ))
                        }

                        Button("Change Master Password") {
                            showingChangePasswordSheet = true
                        }
                        .foregroundColor(.white)

                        Button("Set / Update Backup Password") {
                            showingBackupPasswordSheet = true
                        }
                        .foregroundColor(.white)

                        Picker("Auto-Lock", selection: $prefs.autoLockSeconds) {
                            Text("Immediately on Minimize").tag(0)
                            Text("After 30 Seconds").tag(30)
                            Text("After 1 Minute").tag(60)
                            Text("After 5 Minutes").tag(300)
                        }

                        Picker("Password Health Reminder", selection: Binding(
                            get: { PassReminderService.shared.frequency },
                            set: { PassReminderService.shared.frequency = $0 }
                        )) {
                            ForEach(PassReminderFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }

                        Toggle("Privacy Screen Mask in App Switcher", isOn: $prefs.privacyScreenMask)
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Display & Layout
                    Section("Display & View Modes") {
                        Picker("View Mode", selection: $prefs.viewMode) {
                            ForEach(ViewMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }

                        Picker("Sort Order", selection: $prefs.sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }

                        Picker("Code Grouping", selection: $prefs.codeGrouping) {
                            ForEach(CodeGrouping.allCases) { grouping in
                                Text(grouping.rawValue).tag(grouping)
                            }
                        }

                        Picker("Account Name Position", selection: $prefs.accountNamePosition) {
                            ForEach(AccountNamePosition.allCases) { pos in
                                Text(pos.rawValue).tag(pos)
                            }
                        }

                        Picker("Copy Behavior", selection: $prefs.copyBehavior) {
                            ForEach(CopyBehavior.allCases) { b in
                                Text(b.rawValue).tag(b)
                            }
                        }

                        Toggle("Tap to Reveal Codes", isOn: $prefs.tapToReveal)
                        Toggle("Focus Search on Launch", isOn: $prefs.focusSearchOnLaunch)
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Automatic Backups & Snapshots
                    Section("Automatic Backups & Snapshots") {
                        Toggle("Enable Automatic Backups", isOn: $prefs.autoBackupEnabled)

                        if prefs.autoBackupEnabled {
                            Picker("Retention Limit", selection: $prefs.autoBackupVersionCount) {
                                Text("Keep 5 Versions").tag(5)
                                Text("Keep 10 Versions").tag(10)
                                Text("Keep 25 Versions").tag(25)
                                Text("Keep All (Unlimited)").tag(-1)
                            }

                            NavigationLink {
                                BackupHistoryView()
                            } label: {
                                HStack {
                                    Text("Manage Backup Snapshots")
                                    Spacer()
                                    Text("\(AutoBackupService.shared.snapshots.count) saved")
                                        .foregroundColor(Theme.accentCyan)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Backup & Export
                    Section("Manual Export") {
                        Button {
                            handleExport(format: .encryptedJSON)
                        } label: {
                            Label("Export Encrypted Vault (.json)", systemImage: "lock.doc.fill")
                                .foregroundColor(.white)
                        }

                        Button {
                            handleExport(format: .plainJSON)
                        } label: {
                            Label("Export Plaintext (.json)", systemImage: "doc.text")
                                .foregroundColor(.white)
                        }

                        Button {
                            handleExport(format: .uriList)
                        } label: {
                            Label("Export URI List (.txt)", systemImage: "list.bullet.rectangle")
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Importers
                    Section("Import Tokens") {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Import Backup (2FAS, andOTP, Bitwarden, FreeOTP, Aegis, Authy, WinAuth)", systemImage: "square.and.arrow.down")
                                .foregroundColor(Theme.accentCyan)
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Security Audit Log
                    Section("Security Audit Log") {
                        NavigationLink {
                            AuditLogView()
                        } label: {
                            HStack {
                                Text("View Audit History")
                                Spacer()
                                Text("\(auditLog.logs.count) events")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // MARK: - Danger Zone
                    Section {
                        Button(role: .destructive) {
                            showingWipeAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Wipe Vault & Delete All Data")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "25131A"))

                    // MARK: - App Info
                    Section {
                        VStack(alignment: .center, spacing: 10) {
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Theme.accentBlue.opacity(0.3), radius: 8)

                            Text("Azokle Auth for iOS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Version 1.0 • 100% Offline • GPL v3")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingChangePasswordSheet) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showingBackupPasswordSheet) {
                BackupPasswordView()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(
                        activityItems: [TemporaryExportFile(data: data, filename: exportFilename)],
                        onDismiss: {
                            exportData = nil
                            CleanupTemporaryExportFiles()
                        }
                    )
                }
            }
            .onAppear {
                CleanupTemporaryExportFiles()
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json, .plainText, .commaSeparatedText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("Wipe Entire Vault?", isPresented: $showingWipeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Wipe All Data", role: .destructive) {
                    try? vaultManager.wipeVault()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete your encryption key and all stored 2FA tokens. This action cannot be undone.")
            }
            .alert(statusMessage ?? "", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK") { statusMessage = nil }
            }
            .alert("Encrypted Backup Password", isPresented: $showingImportPasswordPrompt) {
                SecureField("Enter Password", text: $importPasswordInput)
                Button("Import") { handleImportWithPassword() }
                Button("Cancel", role: .cancel) { pendingImportData = nil }
            } message: {
                Text("This file is encrypted. Please enter the backup password to decrypt and import its 2FA tokens.")
            }
        }
    }

    private func handleExport(format: ExportFormat) {
        guard let repo = vaultManager.repository else { return }
        do {
            let data = try VaultExporter.export(repository: repo, format: format)
            self.exportData = data
            self.exportFilename = "azokle-auth-export.\(format.fileExtension)"
            self.showingExportSheet = true
            AuditLogService.shared.record(.vaultExported, reference: format.rawValue)
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                statusMessage = "Permission denied to read selected file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                do {
                    let imported = try UniversalImporter.parse(data: data, fileName: url.lastPathComponent)
                    applyImportedTokens(imported)
                } catch {
                    // Try with password prompt
                    self.pendingImportData = data
                    self.pendingImportFilename = url.lastPathComponent
                    self.importPasswordInput = ""
                    self.showingImportPasswordPrompt = true
                }
            } catch {
                statusMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            statusMessage = "Import error: \(error.localizedDescription)"
        }
    }

    private func handleImportWithPassword() {
        guard let data = pendingImportData else { return }
        do {
            let password = importPasswordInput.isEmpty ? nil : importPasswordInput
            let imported = try UniversalImporter.parse(data: data, fileName: pendingImportFilename, password: password)
            applyImportedTokens(imported)
            pendingImportData = nil
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func applyImportedTokens(_ imported: ImportedVaultResult) {
        for entry in imported.entries {
            try? vaultManager.repository?.addEntry(entry)
        }
        for group in imported.groups {
            _ = try? vaultManager.repository?.addGroup(name: group.name)
        }
        vaultManager.syncEntries()
        statusMessage = "Successfully imported \(imported.entries.count) tokens from \(imported.sourceName)!"
    }
}

// MARK: - Change Master Password Sheet
private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultManager = VaultManager.shared

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 20) {
                    SecureField("New Master Password", text: $newPassword)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    SecureField("Confirm New Password", text: $confirmPassword)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(Theme.accentRed)
                            .font(.system(size: 14))
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Change Master Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard newPassword == confirmPassword else {
                            errorMessage = "Passwords do not match"
                            return
                        }
                        guard newPassword.count >= 6 else {
                            errorMessage = "Password must be at least 6 characters"
                            return
                        }
                        do {
                            try vaultManager.repository?.updatePassword(newPassword: newPassword)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
        }
    }
}

// MARK: - Backup Password Sheet
private struct BackupPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultManager = VaultManager.shared

    @State private var backupPassword = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("A backup password allows unlocking or restoring your vault even if your primary password is lost or shared separately.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    SecureField("Backup Password (Leave empty to remove)", text: $backupPassword)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Backup Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? vaultManager.repository?.setBackupPassword(backupPassword.isEmpty ? nil : backupPassword)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Audit Log View
private struct AuditLogView: View {
    @ObservedObject var auditLog = AuditLogService.shared

    var body: some View {
        ZStack {
            Theme.backgroundDark.ignoresSafeArea()

            if auditLog.logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No Security Events Logged")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                List {
                    ForEach(auditLog.logs) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.eventType.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(itemColor(for: item.eventType))
                                Spacer()
                                Text(item.timestamp, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            if let ref = item.reference {
                                Text(ref)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(item.timestamp, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .listRowBackground(Color(hex: "151D30"))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Audit Log")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear") { auditLog.clear() }
                    .disabled(auditLog.logs.isEmpty)
            }
        }
    }

    private func itemColor(for type: AuditEventType) -> Color {
        switch type {
        case .vaultUnlocked, .vaultBackupCreated, .vaultExported: return Theme.accentCyan
        case .entryShared: return Theme.accentIndigo
        case .failedPassword, .failedBiometrics: return Theme.accentRed
        }
    }
}

// MARK: - Share Sheet Helper
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public var onDismiss: (() -> Void)?

    public init(activityItems: [Any], onDismiss: (() -> Void)? = nil) {
        self.activityItems = activityItems
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private func TemporaryExportFile(data: Data, filename: String) -> URL {
    let uniqueName = UUID().uuidString + "_" + filename
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)
    try? data.write(to: tempURL, options: [.atomic, .completeFileProtection])
    return tempURL
}

private func CleanupTemporaryExportFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
        for file in files where file.lastPathComponent.contains("azokle-auth-export") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
