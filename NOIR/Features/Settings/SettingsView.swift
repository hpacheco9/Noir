//
//  SettingsView.swift
//  NOIR
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.NoirPro.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(L10n.NoirPro.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()

                    Button {
                   
                    } label: {
                        Text(L10n.NoirPro.upgrade)
                            .foregroundColor(Color(uiColor: .systemBackground))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                .padding(.vertical, 8)
            }

            Section(String(localized: L10n.Profile.title)) {
                Button {
                    coordinator.present(SettingsRoutes.Profile(), mode: .medium)
                } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 48, height: 48)

                        Text("H")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Profile.name)
                            .font(.body.weight(.medium))

                        Text(L10n.Profile.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                }
                .tint(.primary)
            }

            Section(String(localized: L10n.Preferences.title)) {
                Picker(selection: $currencyCode) {
                    ForEach(CurrencyPreference.availableCodes, id: \.self) { code in
                        Text(CurrencyPreference.displayName(for: code))
                            .tag(code)
                    }
                } label: {
                    Label {
                        Text(L10n.Preferences.currency)
                    } icon: {
                        Image(systemName: AssetName.System.currency)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsRow(
                    title: L10n.Preferences.shortcuts,
                    systemImage: AssetName.System.shortcuts
                ) {
                    //
                }
            }

            Section(String(localized: L10n.Legal.title)) {
                SettingsRow(
                    title: L10n.Legal.privacyPolicy,
                    systemImage: AssetName.System.privacy
                ) {
                    //coordinator.push(.privacyPolicy)
                }

                SettingsRow(
                    title: L10n.Legal.termsOfService,
                    systemImage: AssetName.System.legal
                ) {
                    //coordinator.push(.termsOfService)
                }
            }
        }
        .navigationTitle(Text(L10n.SettingsView.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction){
                SettingsSheetDismissButton(action: {
                    coordinator.dismiss()
                })
            }
        }
    }
}

private struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                Text(title)

                Spacer()

                Image(systemName: AssetName.System.disclosure)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(Coordinator())
}
