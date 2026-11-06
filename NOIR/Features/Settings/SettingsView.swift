//
//  SettingsView.swift
//  NOIR
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @AppStorage(ProfileStorage.nameKey) private var name = ""
    @Environment(PurchaseStore.self) private var purchaseStore
    @State private var isManagingSubscription = false
    @State private var isRestoring = false
    @State private var restoreAlert: PaywallAlert?
    @State private var isImporterPresented = false
    @State private var isReadingImport = false
    @State private var importErrorMessage: String?
#if DEBUG
    @AppStorage(OnboardingStorage.hasCompletedKey) private var hasCompletedOnboarding = false
    /// The review store isn't observable, so its state is copied here on appear and after each developer action.
    @State private var reviewStatusText = ""
#endif

    private var profileName: String {
        let trimmed = ProfileStorage.trimmed(name)
        return trimmed.isEmpty ? String(localized: L10n.Profile.namePlaceholder) : trimmed
    }

    var body: some View {
        Form {
            Section(String(localized: L10n.Subscription.title)) {
                if purchaseStore.isLifetime {
                    Label {
                        Text(L10n.Subscription.lifetime)
                    } icon: {
                        Image(systemName: AssetName.System.pro)
                            .foregroundStyle(.secondary)
                    }
                }

                if purchaseStore.isSubscriber {
                    SettingsRow(
                        title: L10n.Subscription.manage,
                        systemImage: AssetName.System.pro
                    ) {
                        isManagingSubscription = true
                    }
                }

                SettingsRow(
                    title: L10n.Paywall.restore,
                    systemImage: AssetName.System.restore,
                    accessory: nil,
                    isLoading: isRestoring
                ) {
                    restorePurchases()
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
                    title: L10n.Recurring.title,
                    systemImage: AssetName.System.recurring
                ) {
                    coordinator.navigate(to: SettingsRoutes.recurring())
                }

                SettingsRow(
                    title: L10n.Preferences.shortcuts,
                    systemImage: AssetName.System.shortcuts
                ) {
                    coordinator.navigate(to: SettingsRoutes.shortcuts())
                }
            }

            Section(String(localized: L10n.Export.title)) {
                ShareLink(
                    item: ExpenseCSVExport(
                        container: NOIRApp.sharedModelContainer,
                        headers: .localized,
                        currencyCode: currencyCode
                    ),
                    preview: SharePreview(String(localized: L10n.Export.csv))
                ) {
                    SettingsRowLabel(title: L10n.Export.csv, systemImage: AssetName.System.export)
                }
                .tint(.primary)

                Button {
                    isImporterPresented = true
                } label: {
                    HStack {
                        SettingsRowLabel(title: L10n.Import.csv, systemImage: AssetName.System.importFile)
                        if isReadingImport { ProgressView() }
                    }
                }
                .tint(.primary)
                .disabled(isReadingImport)
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
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .paywallAlert($restoreAlert)
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText]) { result in
            guard case .success(let url) = result else { return }
            Task { await review(url) }
        }
        .alert(Text(L10n.Import.errorTitle), isPresented: .init(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? String(localized: L10n.Shared.unexpectedError))
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

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            let outcome = await purchaseStore.restore()
            isRestoring = false
            restoreAlert = PaywallAlert.report(outcome, restoring: true)
        }
    }
}

private extension SettingsView {
    func review(_ url: URL) async {
        guard !isReadingImport else { return }
        isReadingImport = true
        defer { isReadingImport = false }
        do {
            let parsed = try await ExpenseCSVReader.read(contentsOf: url, currencyCode: currencyCode)
            coordinator.present(SettingsRoutes.importReview(parsed: parsed, currencyCode: currencyCode), mode: .large)
        } catch ExpenseCSVReader.ReadError.missingColumns {
            importErrorMessage = String(localized: L10n.Import.errorColumns)
        } catch {
            importErrorMessage = String(localized: L10n.Import.errorUnreadable)
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
    .environment(PurchaseStore(defaults: nil))
}
