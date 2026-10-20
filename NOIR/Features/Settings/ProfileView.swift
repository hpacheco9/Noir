//
//  ProfileView.swift
//  NOIR
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage("profile.name") private var name = ""
    @AppStorage(HapticsPreference.storageKey) private var hapticsEnabled = HapticsPreference.defaultValue

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

            if HapticsPreference.isSupportedByHardware {
                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        Text(L10n.Preferences.haptics)
                    }
                    .tint(.green)
                } footer: {
                    Text(L10n.Preferences.hapticsFooter)
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
