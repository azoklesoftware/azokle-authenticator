//
//  GroupManagerView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct GroupManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultManager = VaultManager.shared

    @State private var newGroupName = ""
    @State private var editingGroup: VaultGroup?
    @State private var editName = ""
    @State private var showingEditAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Add new group bar
                    HStack(spacing: 12) {
                        TextField("New Category / Group Name", text: $newGroupName)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        Button(action: handleAddGroup) {
                            Text("Add")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.primaryGradient)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // Groups list
                    if vaultManager.groups.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No Groups Created Yet")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(vaultManager.groups) { group in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(Theme.accentCyan)
                                    Text(group.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .listRowBackground(Color(hex: "12141C"))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        handleDeleteGroup(group)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        editingGroup = group
                                        editName = group.name
                                        showingEditAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(Theme.accentIndigo)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Rename Group", isPresented: $showingEditAlert) {
                TextField("Group Name", text: $editName)
                Button("Save") {
                    if let group = editingGroup, !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                        try? vaultManager.repository?.updateGroup(id: group.id, name: editName.trimmingCharacters(in: .whitespaces))
                        vaultManager.syncEntries()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func handleAddGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        _ = try? vaultManager.repository?.addGroup(name: trimmed)
        vaultManager.syncEntries()
        newGroupName = ""
    }

    private func handleDeleteGroup(_ group: VaultGroup) {
        try? vaultManager.repository?.removeGroup(id: group.id)
        vaultManager.syncEntries()
    }
}
