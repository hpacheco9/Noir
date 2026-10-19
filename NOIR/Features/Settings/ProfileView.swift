//
//  ProfileView.swift
//  NOIR
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage("profile.name") private var name = ""

    var body: some View {
        Form {
            Section(String(localized: L10n.Profile.nameSection)) {
                TextField(String(localized: L10n.Profile.namePlaceholder), text: $name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                SettingsRow(
                    title: L10n.Categories.title,
                    systemImage: AssetName.System.categories
                ) {
                    coordinator.navigate(to: SettingsRoutes.categories())
                }
            }
        }
        .navigationTitle(Text(L10n.Profile.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CoordinatorView {
        ProfileView()
    }
    .environmentObject(Coordinator())
}
