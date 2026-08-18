//
//  EditEntryView.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultManager = VaultManager.shared

    private let existingEntry: VaultEntry?
    private let onSave: (VaultEntry) -> Void

    @State private var issuer: String
    @State private var name: String
    @State private var secret: String
    @State private var type: OTPType
    @State private var algo: OTPAlgorithm
    @State private var digits: Int
    @State private var period: Int
    @State private var pin: String
    @State private var note: String
    @State private var isFavorite: Bool
    @State private var selectedGroups: Set<UUID>
    @State private var errorMessage: String?
    @State private var showingIconPicker = false
    @State private var customIcon: String?

    public init(entry: VaultEntry? = nil, onSave: @escaping (VaultEntry) -> Void) {
        self.existingEntry = entry
        self.onSave = onSave

        _issuer = State(initialValue: entry?.issuer ?? "")
        _name = State(initialValue: entry?.name ?? "")
        _secret = State(initialValue: entry?.info.secret ?? "")
        _type = State(initialValue: entry?.type ?? .totp)
        _algo = State(initialValue: entry?.info.algo ?? .sha1)
        _digits = State(initialValue: entry?.info.digits ?? 6)
        _period = State(initialValue: entry?.info.period ?? 30)
        _pin = State(initialValue: entry?.info.pin ?? "")
        _note = State(initialValue: entry?.note ?? "")
        _isFavorite = State(initialValue: entry?.isFavorite ?? false)
        _selectedGroups = State(initialValue: entry?.groups ?? [])
        _customIcon = State(initialValue: entry?.icon)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                Form {
                    // Preview Header
                    Section {
                        HStack(spacing: 16) {
                            Button {
                                showingIconPicker = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.accentCyan.opacity(0.4), Theme.accentIndigo.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)

                                    if let iconName = customIcon, let uiImage = IconManager.shared.loadCustomIcon(filename: iconName) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    } else {
                                        Text(avatarMonogram)
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(issuer.isEmpty ? "New Service" : issuer)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text(name.isEmpty ? "account@example.com" : name)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Spacer()

                            Button {
                                isFavorite.toggle()
                                Theme.triggerHaptic(style: .light)
                            } label: {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundColor(isFavorite ? Theme.favoriteGold : .white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // Account Information
                    Section("Account Information") {
                        TextField("Service / Issuer (e.g. GitHub, Google)", text: $issuer)
                        TextField("Account / Username (e.g. user@domain.com)", text: $name)
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // Token Secret Key
                    Section("Token Secret") {
                        TextField("Secret Key (Base32)", text: $secret)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced))

                        Picker("OTP Type", selection: $type) {
                            ForEach(OTPType.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }

                        if type == .motp || type == .yaotp {
                            SecureField("PIN Code", text: $pin)
                                .keyboardType(.numberPad)
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // Advanced Parameters (Accordion)
                    Section {
                        DisclosureGroup("Advanced Parameters", isExpanded: $showAdvanced) {
                            if type == .totp || type == .hotp {
                                Picker("Algorithm", selection: $algo) {
                                    ForEach(OTPAlgorithm.allCases) { item in
                                        Text(item.rawValue).tag(item)
                                    }
                                }

                                Picker("Digits", selection: $digits) {
                                    Text("6 Digits").tag(6)
                                    Text("7 Digits").tag(7)
                                    Text("8 Digits").tag(8)
                                }
                            }

                            if type == .totp {
                                Picker("Period", selection: $period) {
                                    Text("15 Seconds").tag(15)
                                    Text("30 Seconds (Default)").tag(30)
                                    Text("60 Seconds").tag(60)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    // Categories / Groups
                    if !vaultManager.groups.isEmpty {
                        Section("Categories / Groups") {
                            ForEach(vaultManager.groups) { group in
                                Toggle(group.name, isOn: Binding(
                                    get: { selectedGroups.contains(group.id) },
                                    set: { selected in
                                        if selected {
                                            selectedGroups.insert(group.id)
                                        } else {
                                            selectedGroups.remove(group.id)
                                        }
                                    }
                                ))
                            }
                        }
                        .listRowBackground(Color(hex: "12141C"))
                    }

                    // Notes
                    Section("Notes") {
                        TextField("Optional security notes...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .listRowBackground(Color(hex: "12141C"))

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(Theme.accentRed)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(existingEntry == nil ? "Add 2FA Token" : "Edit 2FA Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accentCyan)
                }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(
                    issuer: issuer,
                    onSelectCustomImage: { img in
                        let tokenID = existingEntry?.id ?? UUID()
                        if let filename = IconManager.shared.saveCustomIcon(id: tokenID, image: img) {
                            customIcon = filename
                        }
                    },
                    onSelectBrand: { brand in
                        // When a brand is selected, we can set the issuer or a brand icon
                        if issuer.isEmpty { issuer = brand.name }
                    },
                    onRemove: {
                        if let filename = customIcon {
                            IconManager.shared.deleteCustomIcon(filename: filename)
                        }
                        customIcon = nil
                    }
                )
            }
        }
    }

    private var avatarMonogram: String {
        let title = issuer.isEmpty ? name : issuer
        return String(title.prefix(1)).uppercased()
    }

    private func handleSave() {
        let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard !cleanSecret.isEmpty else {
            errorMessage = "Secret key cannot be empty"
            return
        }

        guard Base32.decode(cleanSecret) != nil || Hex.decode(cleanSecret) != nil else {
            errorMessage = "Invalid Base32 secret key format"
            return
        }

        let info = OtpInfoModel(
            secret: cleanSecret,
            algo: algo,
            digits: digits,
            period: period,
            counter: existingEntry?.info.counter ?? 0,
            pin: pin.isEmpty ? nil : pin
        )

        let entry = VaultEntry(
            id: existingEntry?.id ?? UUID(),
            type: type,
            name: name.trimmingCharacters(in: .whitespaces),
            issuer: issuer.trimmingCharacters(in: .whitespaces),
            note: note,
            isFavorite: isFavorite,
            icon: customIcon,
            info: info,
            groups: selectedGroups,
            usageCount: existingEntry?.usageCount ?? 0,
            lastUsedTimestamp: existingEntry?.lastUsedTimestamp ?? 0
        )

        onSave(entry)
        Theme.triggerNotificationHaptic(type: .success)
        dismiss()
    }
}
