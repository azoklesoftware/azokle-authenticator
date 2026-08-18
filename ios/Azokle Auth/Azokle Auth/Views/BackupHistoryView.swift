//
//  BackupHistoryView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI

public struct BackupHistoryView: View {
    @ObservedObject var backupService = AutoBackupService.shared
    @ObservedObject var vaultManager = VaultManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var sharingURL: URL?
    @State private var showingShareSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    if backupService.snapshots.isEmpty {
                        emptyState
                    } else {
                        List {
                            Section {
                                ForEach(backupService.snapshots) { snapshot in
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Theme.accentCyan.opacity(0.15))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: "lock.doc.fill")
                                                .foregroundColor(Theme.accentCyan)
                                                .font(.system(size: 18))
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(snapshot.formattedDate)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)

                                            Text("\(snapshot.entryCount) token\(snapshot.entryCount == 1 ? "" : "s") • \(snapshot.formattedSize)")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }

                                        Spacer()

                                        Button {
                                            sharingURL = snapshot.fileURL
                                            showingShareSheet = true
                                        } label: {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundColor(Theme.accentCyan)
                                                .font(.system(size: 16))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color(hex: "12141C"))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            backupService.deleteSnapshot(snapshot)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text("Encrypted Vault Snapshots (\(backupService.snapshots.count))")
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }

                    // Create Snapshot Button
                    VStack {
                        Button {
                            if let vaultData = vaultManager.repository?.rawFileData {
                                backupService.createSnapshot(vaultData: vaultData)
                                Theme.triggerNotificationHaptic(type: .success)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.shield.fill")
                                Text("Create Encrypted Snapshot Now")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.primaryGradient)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Backup History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = sharingURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onAppear {
                backupService.reloadSnapshots()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Automatic Snapshots Yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Encrypted snapshots are automatically created whenever tokens are added or updated.")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
