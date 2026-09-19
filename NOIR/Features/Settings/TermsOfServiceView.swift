//
//  TermsOfServiceView.swift
//  NOIR
//

import SwiftUI

struct TermsOfServiceView: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Form {
            Section {
                Text(L10n.TermsOfServiceView.description)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(L10n.Legal.termsOfService))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SettingsSheetDismissButton(action: coordinator.dismiss)
            }
        }
    }
}
