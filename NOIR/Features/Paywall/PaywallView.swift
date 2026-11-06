//
//  PaywallView.swift
//  NOIR
//

import SwiftUI

struct PaywallView: View {
    @Environment(PurchaseStore.self) private var store
    @State private var selection: PaywallPlan?
    @State private var isBusy = false
    @State private var alert: PaywallAlert?
    @State private var legalLink: LegalLink?

    private var plan: PaywallPlan? {
        let available = store.availablePlans
        if let selection, available.contains(selection) { return selection }
        return PaywallPlan.initialSelection(hasTrial: store.trialLength != nil, available: available)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                plans

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
        .sheet(item: $legalLink) { link in
            SafariRouteContent(url: link.url)
        }
        .paywallAlert($alert)
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

                Text(L10n.Paywall.subtitle)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var plans: some View {
        if store.productsFailed {
            VStack(spacing: 12) {
                Text(L10n.Paywall.productsFailed)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(String(localized: L10n.Dashboard.retry)) {
                    run { await store.refresh() }
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else if store.availablePlans.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 10) {
                ForEach(store.availablePlans) { option in
                    PaywallPlanRow(
                        plan: option,
                        price: store.price(for: option),
                        trialLength: store.trialLength,
                        isSelected: option == plan
                    ) {
                        Haptics.play(.tap)
                        selection = option
                    }
                    .disabled(isBusy)
                }
            }
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button {
                guard let plan else { return }
                Haptics.play(.tap)
                run(restoring: false) { await store.purchase(plan) }
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                    } else if let plan {
                        Text(plan.callToAction(hasTrial: store.trialLength != nil))
                            .font(.body.weight(.semibold))
                    } else {
                        Text(L10n.Paywall.CallToAction.subscribe)
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .tint(.primary)
            .buttonStyle(.glassProminent)
            .disabled(plan == nil || isBusy)

            if plan == .monthly, let trialLength = store.trialLength, let price = store.price(for: .monthly) {
                let caption = PaywallPlan.trialCaption(trialLength: trialLength, price: price.total)
                Text(caption.text)
                    .font(.footnote.weight(.medium))
                    .accessibilityLabel(Text(caption.spoken))
            }

            Text((plan ?? .yearly).disclosure)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            footerLinks
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var footerLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                restoreButton
                separator
                legalButton(.termsOfUse)
                separator
                legalButton(.privacyPolicy)
            }

            VStack(spacing: 0) {
                restoreButton
                legalButton(.termsOfUse)
                legalButton(.privacyPolicy)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    private var separator: some View {
        Text(verbatim: "·").accessibilityHidden(true)
    }

    private var restoreButton: some View {
        Button {
            run(restoring: true) { await store.restore() }
        } label: {
            Text(L10n.Paywall.restore)
                .frame(minHeight: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func legalButton(_ link: LegalLink) -> some View {
        Button {
            legalLink = link
        } label: {
            Text(link.title)
                .frame(minHeight: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func run(restoring: Bool, _ work: @escaping () async -> PurchaseOutcome) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            let outcome = await work()
            isBusy = false
            alert = PaywallAlert.report(outcome, restoring: restoring)
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            await work()
            isBusy = false
        }
    }
}

private struct PaywallPlanRow: View {
    let plan: PaywallPlan
    let price: PurchaseStore.Price?
    let trialLength: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? AssetName.System.selected : AssetName.System.unselected)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let price {
                        let billed = plan.priceLine(price.total)
                        Text(billed.text)
                            .font(.headline)
                            .accessibilityLabel(Text(billed.spoken))

                        if let secondary = plan.secondaryLine(price: price, trialLength: trialLength) {
                            Text(secondary.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(Text(secondary.spoken))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: shape)
            .overlay { shape.strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum LegalLink: Identifiable {
    case termsOfUse, privacyPolicy

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .termsOfUse: L10n.Legal.termsOfUse
        case .privacyPolicy: L10n.Legal.privacyPolicy
        }
    }

    var url: URL {
        switch self {
        case .termsOfUse: AppLinks.termsOfUse
        case .privacyPolicy: AppLinks.privacyPolicy
        }
    }
}

private enum PaywallFeature: CaseIterable, Identifiable {
    case insights, widgets, shortcuts, categories, privacy

    var id: Self { self }

    var symbol: String {
        switch self {
        case .insights: AssetName.System.dashboard
        case .widgets: AssetName.System.widgets
        case .shortcuts: AssetName.System.applePay
        case .categories: AssetName.System.tag
        case .privacy: AssetName.System.privacy
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .insights: L10n.Paywall.Feature.insightsTitle
        case .widgets: L10n.Paywall.Feature.widgetsTitle
        case .shortcuts: L10n.Paywall.Feature.shortcutsTitle
        case .categories: L10n.Paywall.Feature.categoriesTitle
        case .privacy: L10n.Paywall.Feature.privacyTitle
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .insights: L10n.Paywall.Feature.insightsDescription
        case .widgets: L10n.Paywall.Feature.widgetsDescription
        case .shortcuts: L10n.Paywall.Feature.shortcutsDescription
        case .categories: L10n.Paywall.Feature.categoriesDescription
        case .privacy: L10n.Paywall.Feature.privacyDescription
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
    PaywallView()
        .environment(PurchaseStore(defaults: nil))
}
