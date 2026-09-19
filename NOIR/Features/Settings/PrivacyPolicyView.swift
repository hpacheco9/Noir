//
//  PrivacyPolicyView.swift
//  NOIR
//

import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Form {
            Section {
                Text(L10n.PrivacyPolicyView.description)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(L10n.Legal.privacyPolicy))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SettingsSheetDismissButton(action: coordinator.dismiss)
            }
        }
    }
}
