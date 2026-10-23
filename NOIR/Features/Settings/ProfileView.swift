//
//  ProfileView.swift
//  NOIR
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(ProfileStorage.nameKey) private var name = ""
    @AppStorage(HapticsPreference.storageKey) private var hapticsEnabled = HapticsPreference.defaultValue
    @State private var draftName = ""
    @State private var nameOnAppear = ""

    var body: some View {
        Form {
            Section(String(localized: L10n.Profile.nameSection)) {
                TextField(String(localized: L10n.Profile.namePlaceholder), text: $draftName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(finishEditing)
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
        .onAppear {
            nameOnAppear = name
            draftName = name
        }
        .onChange(of: draftName) { _, draft in
            name = ProfileStorage.nameToStore(draft: draft, current: name)
        }
        .onDisappear(perform: finishEditing)
    }

    private func finishEditing() {
        name = ProfileStorage.nameOnLeaving(draft: draftName, entry: nameOnAppear)
        draftName = name
    }
}

#Preview {
    CoordinatorView {
        ProfileView()
    }
    .environmentObject(Coordinator())
}
