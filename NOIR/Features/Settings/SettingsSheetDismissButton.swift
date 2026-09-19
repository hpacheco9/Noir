//
//  SettingsSheetDismissButton.swift
//  NOIR
//

import SwiftUI

struct SettingsSheetDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: AssetName.System.close)
        }
        .accessibilityLabel(Text(L10n.Shared.close))
    }
}
