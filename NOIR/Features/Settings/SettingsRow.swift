//
//  SettingsRow.swift
//  NOIR
//

import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    var detail: String?
    var accessory = AssetName.System.disclosure
    var largeIcon = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(
                title: title,
                systemImage: systemImage,
                detail: detail,
                accessory: accessory,
                largeIcon: largeIcon
            )
        }
        .tint(.primary)
    }
}

// The row's look, for controls that are not a plain `Button` (e.g. `ShareLink`).
struct SettingsRowLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    var detail: String?
    var accessory: String?
    var largeIcon = false

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

            if let accessory {
                Image(systemName: accessory)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
