//
//  ShortcutsView.swift
//  NOIR
//

import SwiftUI

struct ShortcutsView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(IntentSummaryPreference.storageKey) private var intentSummaryEnabled = IntentSummaryPreference.defaultValue

    var body: some View {
        Form {
            Section {
                Text(L10n.ShortcutsView.description)
                    .foregroundStyle(.secondary)
            }

            Section {
                SettingsRow(
                    title: L10n.ShortcutsView.applePayTitle,
                    systemImage: AssetName.System.applePay,
                    subtitle: L10n.ShortcutsView.applePayDescription,
                    accessory: AssetName.System.externalLink
                ) {
                    coordinator.present(SettingsRoutes.safari(url: AppLinks.walletAutomationGuide), mode: .large)
                }

                SettingsRow(
                    title: L10n.ShortcutsView.addExpenseTitle,
                    systemImage: AssetName.System.shortcutGuide,
                    subtitle: L10n.ShortcutsView.addExpenseDescription,
                    accessory: AssetName.System.externalLink
                ) {
                    coordinator.present(SettingsRoutes.safari(url: AppLinks.shortcutsGuide), mode: .large)
                }
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
