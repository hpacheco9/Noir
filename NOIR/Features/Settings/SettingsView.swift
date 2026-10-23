//
//  SettingsView.swift
//  NOIR
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @AppStorage(ProfileStorage.nameKey) private var name = ""
#if DEBUG
    @AppStorage(OnboardingStorage.hasCompletedKey) private var hasCompletedOnboarding = false
    /// The review store isn't observable, so its state is copied here on appear and after each developer action.
    @State private var reviewStatusText = ""
#endif

    private static let showsProCard = false

    private var profileName: String {
        let trimmed = ProfileStorage.trimmed(name)
        return trimmed.isEmpty ? String(localized: L10n.Profile.namePlaceholder) : trimmed
    }

    var body: some View {
        Form {
            if Self.showsProCard {
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
            }

            Section(String(localized: L10n.Profile.title)) {
                Button {
                    coordinator.navigate(to: SettingsRoutes.Profile())
                } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 48, height: 48)

                        let initial = ProfileStorage.initial(of: name)
                        if initial.isEmpty {
                            Image(systemName: AssetName.System.person)
                        } else {
                            Text(verbatim: initial)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: profileName)
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
                    coordinator.navigate(to: SettingsRoutes.shortcuts())
                }
            }

            Section(String(localized: L10n.Legal.title)) {
                SettingsRow(
                    title: L10n.Legal.privacyPolicy,
                    systemImage: AssetName.System.privacy
                ) {
                    coordinator.present(SettingsRoutes.safari(url: AppLinks.privacyPolicy), mode: .large)
                }

                SettingsRow(
                    title: L10n.Legal.termsOfService,
                    systemImage: AssetName.System.legal
                ) {
                    coordinator.present(SettingsRoutes.safari(url: AppLinks.termsOfService), mode: .large)
                }
            }

#if DEBUG
            Section {
                // NOIRApp swaps RootView (and this sheet with it) for MainOnboarding as soon as the flag flips.
                Button(role: .destructive) {
                    hasCompletedOnboarding = false
                } label: {
                    Label {
                        Text(verbatim: "Reset onboarding")
                    } icon: {
                        Image(systemName: AssetName.System.reset)
                    }
                }
            } header: {
                Text(verbatim: "Developer")
            }

            reviewPromptDeveloperSection
#endif
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

#if DEBUG
// MARK: - Developer: review prompt

private extension SettingsView {
    /// Checks the App Store review prompt without logging real expenses. Debug builds always show the system prompt
    /// when asked (TestFlight never does).
    var reviewPromptDeveloperSection: some View {
        let store = ReviewPromptStore()

        return Section {
            Text(verbatim: reviewStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .onAppear { reviewStatusText = reviewStatus(store) }

            Button(role: .destructive) {
                store.reset()
                reviewStatusText = reviewStatus(store)
            } label: {
                Label {
                    Text(verbatim: "Reset review prompt")
                } icon: {
                    Image(systemName: AssetName.System.reset)
                }
            }
        } header: {
            Text(verbatim: "Review prompt")
        }
    }

    func reviewStatus(_ store: ReviewPromptStore) -> String {
        let asked = store.lastPromptDate.map {
            "asked for \(store.lastPromptedVersion ?? "?") on \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? "never asked"
        return "\(store.createdCount) expenses counted · \(asked) · version \(AppVersion.current())"
    }
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(Coordinator())
}
