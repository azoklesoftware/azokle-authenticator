//
//  MainVaultView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct MainVaultView: View {
    @ObservedObject var vaultManager = VaultManager.shared
    @ObservedObject var prefs = PreferencesStore.shared

    @State private var searchQuery = ""
    @State private var selectedGroupId: UUID? = nil
    @State private var showingScanner = false
    @State private var showingAddManual = false
    @State private var editingEntry: VaultEntry?
    @State private var showingSettings = false
    @State private var showingGroupManager = false
    @State private var entryToDelete: VaultEntry?
    @State private var showingDeleteAlert = false
    @State private var currentTime = Date().timeIntervalSince1970

    @State private var showingTransferView = false
    @State private var showingPassReminder = false

    // Toast Notification State
    @State private var showToast = false
    @State private var toastMessage = "Copied to clipboard • Clears in 30s"

    // Multi-select Batch Actions State
    @State private var isSelectionMode = false
    @State private var selectedEntryIds: Set<UUID> = []

    // 0.5-second timer for TOTP animation updates
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Group Filter Chips Carousel
                    groupFilterChips
                        .padding(.bottom, 8)

                    // Main Content (List / Grid / Empty)
                    if filteredEntries.isEmpty {
                        emptyStateView
                    } else {
                        entriesContainer
                    }
                }

                // Floating Action Button (FAB)
                if !isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Menu {
                                Button {
                                    showingScanner = true
                                } label: {
                                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                                }

                                Button {
                                    showingAddManual = true
                                } label: {
                                    Label("Add Manually", systemImage: "square.and.pencil")
                                }

                                if !vaultManager.entries.isEmpty {
                                    Button {
                                        showingTransferView = true
                                    } label: {
                                        Label("Transfer Tokens Offline", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Theme.primaryGradient)
                                        .frame(width: 58, height: 58)
                                        .shadow(color: Theme.accentCyan.opacity(0.4), radius: 12, y: 6)

                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }

                // Batch Selection Action Bar
                if isSelectionMode {
                    VStack {
                        Spacer()
                        batchActionBar
                    }
                }

                // Toast Notification Overlay
                if showToast {
                    VStack {
                        CopyToastView(message: toastMessage)
                            .padding(.top, 10)
                        Spacer()
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showToast)
                }
            }
            .navigationTitle("Azokle Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Theme.triggerHaptic(style: .medium)
                        vaultManager.lock()
                    }) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Theme.accentCyan)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if !vaultManager.entries.isEmpty {
                            Button {
                                withAnimation {
                                    isSelectionMode.toggle()
                                    selectedEntryIds.removeAll()
                                }
                            } label: {
                                Text(isSelectionMode ? "Done" : "Select")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.accentCyan)
                            }
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView { newEntries in
                    for entry in newEntries {
                        try? vaultManager.repository?.addEntry(entry)
                    }
                    vaultManager.syncEntries()
                    triggerAutoBackup()
                    displayToast(message: "Imported \(newEntries.count) token\(newEntries.count == 1 ? "" : "s")")
                }
            }
            .sheet(isPresented: $showingAddManual) {
                EditEntryView { newEntry in
                    try? vaultManager.repository?.addEntry(newEntry)
                    vaultManager.syncEntries()
                    triggerAutoBackup()
                    displayToast(message: "Added \(newEntry.issuer.isEmpty ? newEntry.name : newEntry.issuer)")
                }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry) { updated in
                    try? vaultManager.repository?.updateEntry(updated)
                    vaultManager.syncEntries()
                    triggerAutoBackup()
                    displayToast(message: "Saved changes")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingGroupManager) {
                GroupManagerView()
            }
            .sheet(isPresented: $showingTransferView) {
                TransferView(entries: isSelectionMode && !selectedEntryIds.isEmpty
                    ? vaultManager.entries.filter { selectedEntryIds.contains($0.id) }
                    : vaultManager.entries
                )
            }
            .sheet(isPresented: $showingPassReminder) {
                PassReminderSheet {
                    displayToast(message: "Master password verified")
                }
            }
            .onAppear {
                if PassReminderService.shared.isReminderDue {
                    showingPassReminder = true
                }
            }
            .alert("Delete 2FA Token?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let item = entryToDelete {
                        try? vaultManager.repository?.removeEntry(id: item.id)
                        vaultManager.syncEntries()
                        displayToast(message: "Token deleted")
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(entryToDelete?.issuer ?? entryToDelete?.name ?? "this token")\"?")
            }
            .onReceive(timer) { _ in
                currentTime = Date().timeIntervalSince1970
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.45))

            TextField("Search by name, issuer, note...", text: $searchQuery)
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "12141C"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "1E2336"), lineWidth: 1)
        )
    }

    // MARK: - Group Filter Chips
    private var groupFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Tokens Chip
                groupChip(
                    title: "All",
                    count: vaultManager.entries.count,
                    isSelected: selectedGroupId == nil
                ) {
                    Theme.triggerHaptic(style: .light)
                    selectedGroupId = nil
                }

                // User Groups
                ForEach(vaultManager.groups) { group in
                    let count = vaultManager.entries.filter { $0.groups.contains(group.id) }.count
                    groupChip(
                        title: group.name,
                        count: count,
                        isSelected: selectedGroupId == group.id
                    ) {
                        Theme.triggerHaptic(style: .light)
                        selectedGroupId = group.id
                    }
                }

                // Manage Groups Button
                Button(action: { showingGroupManager = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Groups")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(20)
                    .foregroundColor(Theme.accentCyan)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func groupChip(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.black.opacity(0.25) : Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accentCyan : Color(hex: "12141C"))
            .foregroundColor(isSelected ? Theme.backgroundDark : .white.opacity(0.85))
            .cornerRadius(20)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(hex: "1E2336"), lineWidth: 1)
            )
        }
    }

    // MARK: - Entries Container
    private var entriesContainer: some View {
        ScrollView {
            if prefs.viewMode == .tiles {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filteredEntries) { entry in
                        let progress = entry.currentProgress(timestamp: currentTime)
                        HStack {
                            if isSelectionMode {
                                selectionCheckbox(for: entry.id)
                            }
                            EntryCardView(
                                entry: entry,
                                progress: progress,
                                viewMode: .tiles,
                                onCopy: {
                                    try? vaultManager.repository?.incrementUsage(for: entry.id)
                                    displayToast(message: "Copied • Clears in 30s")
                                },
                                onEdit: { editingEntry = entry },
                                onToggleFavorite: {
                                    try? vaultManager.repository?.toggleFavorite(for: entry.id)
                                    vaultManager.syncEntries()
                                },
                                onDelete: {
                                    entryToDelete = entry
                                    showingDeleteAlert = true
                                },
                                onIncrementCounter: {
                                    var updated = entry
                                    updated.info.counter += 1
                                    try? vaultManager.repository?.updateEntry(updated)
                                    vaultManager.syncEntries()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
            } else {
                LazyVStack(spacing: prefs.viewMode == .compact ? 8 : (prefs.viewMode == .small ? 6 : 12)) {
                    ForEach(filteredEntries) { entry in
                        let progress = entry.currentProgress(timestamp: currentTime)
                        HStack {
                            if isSelectionMode {
                                selectionCheckbox(for: entry.id)
                            }
                            EntryCardView(
                                entry: entry,
                                progress: progress,
                                viewMode: prefs.viewMode,
                                onCopy: {
                                    try? vaultManager.repository?.incrementUsage(for: entry.id)
                                    displayToast(message: "Copied • Clears in 30s")
                                },
                                onEdit: { editingEntry = entry },
                                onToggleFavorite: {
                                    try? vaultManager.repository?.toggleFavorite(for: entry.id)
                                    vaultManager.syncEntries()
                                },
                                onDelete: {
                                    entryToDelete = entry
                                    showingDeleteAlert = true
                                },
                                onIncrementCounter: {
                                    var updated = entry
                                    updated.info.counter += 1
                                    try? vaultManager.repository?.updateEntry(updated)
                                    vaultManager.syncEntries()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Multi-Select Checkbox & Batch Bar
    private func selectionCheckbox(for id: UUID) -> some View {
        Button {
            Theme.triggerHaptic(style: .light)
            if selectedEntryIds.contains(id) {
                selectedEntryIds.remove(id)
            } else {
                selectedEntryIds.insert(id)
            }
        } label: {
            Image(systemName: selectedEntryIds.contains(id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(selectedEntryIds.contains(id) ? Theme.accentCyan : .white.opacity(0.4))
        }
    }

    private var batchActionBar: some View {
        HStack(spacing: 20) {
            Text("\(selectedEntryIds.count) selected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                guard !selectedEntryIds.isEmpty else { return }
                for id in selectedEntryIds {
                    try? vaultManager.repository?.toggleFavorite(for: id)
                }
                vaultManager.syncEntries()
                selectedEntryIds.removeAll()
                isSelectionMode = false
            } label: {
                Label("Favorite", systemImage: "star.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.favoriteGold)
            }

            Button(role: .destructive) {
                guard !selectedEntryIds.isEmpty else { return }
                for id in selectedEntryIds {
                    try? vaultManager.repository?.removeEntry(id: id)
                }
                vaultManager.syncEntries()
                selectedEntryIds.removeAll()
                isSelectionMode = false
                displayToast(message: "Deleted selected tokens")
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.accentRed)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "181B26"))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .shadow(color: Color.black.opacity(0.4), radius: 12)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accentBlue.opacity(0.12))
                    .frame(width: 100, height: 100)

                if searchQuery.isEmpty {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(Theme.accentCyan)
                }
            }

            VStack(spacing: 8) {
                Text(searchQuery.isEmpty ? "Your Vault is Empty" : "No Matching Tokens Found")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(searchQuery.isEmpty ? "Scan a QR code or add an account manually to get started." : "Check your search query or try selecting a different category.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if searchQuery.isEmpty {
                HStack(spacing: 16) {
                    Button(action: { showingScanner = true }) {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Theme.primaryGradient)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }

                    Button(action: { showingAddManual = true }) {
                        Label("Add Manual", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Toast Helper
    private func displayToast(message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }

    private func triggerAutoBackup() {
        guard prefs.autoBackupEnabled else { return }
        if let data = vaultManager.repository?.rawFileData {
            AutoBackupService.shared.createSnapshot(vaultData: data, retentionLimit: prefs.autoBackupVersionCount)
        }
    }

    // MARK: - Filtering & Sorting Logic
    private var filteredEntries: [VaultEntry] {
        var list = vaultManager.entries

        // 1. Group filtering
        if let groupId = selectedGroupId {
            list = list.filter { $0.groups.contains(groupId) }
        }

        // 2. Search query filtering
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { entry in
                var matches = false
                if prefs.searchInIssuer && entry.issuer.lowercased().contains(q) { matches = true }
                if prefs.searchInName && entry.name.lowercased().contains(q) { matches = true }
                if prefs.searchInNotes && entry.note.lowercased().contains(q) { matches = true }
                if prefs.searchInGroups {
                    let groupNames = entry.groups.compactMap { gid in vaultManager.groups.first(where: { $0.id == gid })?.name.lowercased() }
                    if groupNames.contains(where: { $0.contains(q) }) { matches = true }
                }
                return matches
            }
        }

        // 3. Sorting
        switch prefs.sortOrder {
        case .custom:
            return list.sorted { ($0.isFavorite ? 1 : 0) > ($1.isFavorite ? 1 : 0) }
        case .alphabetical:
            return list.sorted {
                let name0 = $0.issuer.isEmpty ? $0.name : $0.issuer
                let name1 = $1.issuer.isEmpty ? $1.name : $1.issuer
                return name0.localizedCaseInsensitiveCompare(name1) == .orderedAscending
            }
        case .usage:
            return list.sorted { $0.usageCount > $1.usageCount }
        case .lastUsed:
            return list.sorted { $0.lastUsedTimestamp > $1.lastUsedTimestamp }
        }
    }
}
