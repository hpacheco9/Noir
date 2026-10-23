//
//  PaywallView.swift
//  NOIR
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    /// Placeholder until StoreKit supplies the real product price.
    private static let mockPrice = 9.99

    private var priceText: String {
        CurrencyPreference.string(for: Self.mockPrice, code: currencyCode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(PaywallFeature.allCases) { feature in
                        PaywallFeatureRow(feature: feature)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    coordinator.dismiss()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: AssetName.System.pro)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 84, height: 84)
                .background(.primary, in: .rect(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L10n.Paywall.title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(L10n.NoirPro.description)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var purchaseBar: some View {
        VStack(spacing: 4) {
            Button {
                // Mock: StoreKit isn't wired yet.
                Haptics.play(.tap)
            } label: {
                Text(L10n.Paywall.unlock(price: priceText))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .tint(.primary)
            .buttonStyle(.glassProminent)

            Button {
                // Mock: StoreKit isn't wired yet.
            } label: {
                Text(L10n.Paywall.restore)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                legalLink(L10n.Legal.termsOfService, url: AppLinks.termsOfService)

                Text(verbatim: "·")

                legalLink(L10n.Legal.privacyPolicy, url: AppLinks.privacyPolicy)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func legalLink(_ title: LocalizedStringResource, url: URL) -> some View {
        Button {
            coordinator.present(SettingsRoutes.safari(url: url), mode: .large)
        } label: {
            Text(title)
                .frame(minHeight: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private enum PaywallFeature: CaseIterable, Identifiable {
    case sync, categories, widgets, insights, export

    var id: Self { self }

    var symbol: String {
        switch self {
        case .sync: AssetName.System.iCloud
        case .categories: AssetName.System.tag
        case .widgets: AssetName.System.widgets
        case .insights: AssetName.System.dashboard
        case .export: AssetName.System.export
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .sync: L10n.Paywall.Feature.syncTitle
        case .categories: L10n.Paywall.Feature.categoriesTitle
        case .widgets: L10n.Paywall.Feature.widgetsTitle
        case .insights: L10n.Paywall.Feature.insightsTitle
        case .export: L10n.Paywall.Feature.exportTitle
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .sync: L10n.Paywall.Feature.syncDescription
        case .categories: L10n.Paywall.Feature.categoriesDescription
        case .widgets: L10n.Paywall.Feature.widgetsDescription
        case .insights: L10n.Paywall.Feature.insightsDescription
        case .export: L10n.Paywall.Feature.exportDescription
        }
    }
}

private struct PaywallFeatureRow: View {
    let feature: PaywallFeature

    @ScaledMetric(relativeTo: .title3) private var iconSize = 46

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: iconSize, height: iconSize)
                .background(.quaternary, in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)

                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CoordinatorView {
        PaywallView()
    }
    .environmentObject(Coordinator())
}
