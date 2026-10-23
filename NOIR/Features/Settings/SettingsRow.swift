//
//  SettingsRow.swift
//  NOIR
//

import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                Text(title)

                Spacer()

                Image(systemName: AssetName.System.disclosure)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}
