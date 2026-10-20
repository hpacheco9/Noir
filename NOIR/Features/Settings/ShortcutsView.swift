//
//  ShortcutsView.swift
//  NOIR
//

import SwiftUI

struct ShortcutsView: View {
    @AppStorage(IntentSummaryPreference.storageKey) private var intentSummaryEnabled = IntentSummaryPreference.defaultValue

    var body: some View {
        Form {
            Section {
                Text(L10n.ShortcutsView.description)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $intentSummaryEnabled) {
                    Label {
                        Text(L10n.Preferences.intentSummary)
                    } icon: {
                        Image(systemName: AssetName.System.intentSummary)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(SettingsView.toggleTint)
            }
        }
        .navigationTitle(Text(L10n.Preferences.shortcuts))
        .navigationBarTitleDisplayMode(.inline)
    }
}
