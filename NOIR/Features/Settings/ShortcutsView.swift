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
                    Text(L10n.Preferences.intentSummary)
                }
                .tint(.green)
            } footer: {
                Text(L10n.Preferences.intentSummaryFooter)
            }
        }
        .navigationTitle(Text(L10n.Preferences.shortcuts))
        .navigationBarTitleDisplayMode(.inline)
    }
}
