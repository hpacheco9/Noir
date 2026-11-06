//
//  SettingsRow.swift
//  NOIR
//

import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    var detail: String?
    var accessory: String? = AssetName.System.disclosure
    var largeIcon = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(
                title: title,
                systemImage: systemImage,
                detail: detail,
                accessory: accessory,
                largeIcon: largeIcon,
                isLoading: isLoading
            )
        }
        .tint(.primary)
        .disabled(isLoading)
    }
}

struct SettingsRowLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    var detail: String?
    var accessory: String?
    var largeIcon = false
    var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(largeIcon ? .title2 : nil)
                .foregroundStyle(.secondary)

            Text(title)

            Spacer()

            if let detail {
                Text(verbatim: detail)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
            } else if let accessory {
                Image(systemName: accessory)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
