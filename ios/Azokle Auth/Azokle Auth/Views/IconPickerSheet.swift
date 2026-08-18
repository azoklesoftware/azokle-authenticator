//
//  IconPickerSheet.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import PhotosUI

public struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let issuer: String
    public let onSelectCustomImage: (UIImage) -> Void
    public let onSelectBrand: (BrandSuggestion) -> Void
    public let onRemove: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?

    public init(
        issuer: String,
        onSelectCustomImage: @escaping (UIImage) -> Void,
        onSelectBrand: @escaping (BrandSuggestion) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.issuer = issuer
        self.onSelectCustomImage = onSelectCustomImage
        self.onSelectBrand = onSelectBrand
        self.onRemove = onRemove
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Custom Photo Picker Button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.accentCyan)

                                Text("Choose Image from Photo Library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 14)
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    onSelectCustomImage(image)
                                    dismiss()
                                }
                            }
                        }

                        // Suggested Match
                        if let suggested = IconManager.matchBrand(for: issuer) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested for \"\(issuer)\"")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.accentCyan)

                                Button {
                                    onSelectBrand(suggested)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: suggested.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: suggested.sfSymbol)
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                        }

                                        Text(suggested.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .glassCard(cornerRadius: 14, isHighlighted: true)
                                }
                            }
                        }

                        // Popular Brand Icons Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Popular Brand Icons")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(IconManager.brands) { brand in
                                    Button {
                                        onSelectBrand(brand)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle()
                                                    .fill(LinearGradient(colors: brand.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .frame(width: 36, height: 36)

                                                Image(systemName: brand.sfSymbol)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                            }

                                            Text(brand.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            Spacer()
                                        }
                                        .padding(10)
                                        .glassCard(cornerRadius: 12)
                                    }
                                }
                            }
                        }

                        // Remove Icon Option
                        Button(role: .destructive) {
                            onRemove()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Remove Custom Icon (Use Monogram)")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(hex: "25131A"))
                            .cornerRadius(12)
                            .foregroundColor(Theme.accentRed)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
