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

                Image(systemName: accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}
