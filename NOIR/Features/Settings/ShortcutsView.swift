//
//  ShortcutsView.swift
//  NOIR
//

import SwiftUI

struct ShortcutsView: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Form {
            Section {
                Text(L10n.ShortcutsView.description)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(L10n.Preferences.shortcuts))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SettingsSheetDismissButton(action: coordinator.dismiss)
            }
        }
    }
}
