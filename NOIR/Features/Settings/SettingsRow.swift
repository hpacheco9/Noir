//
//  SettingsRow.swift
//  NOIR
//

import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    var subtitle: LocalizedStringResource?
    var detail: String?
    var accessory = AssetName.System.disclosure
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                if let subtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(title)
                }

                Spacer()

                if let detail {
                    Text(verbatim: detail)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}
