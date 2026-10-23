//
//  CurrencyView.swift
//  NOIR
//

import SwiftUI

struct CurrencyView: View {
    @Binding var currencyCode: String
    @State private var isAppeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Same header as the name, budget and notifications steps.
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Onboarding.currencyTitle)
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)

                Text(L10n.Onboarding.currencySubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .fixedSize(horizontal: false, vertical: true)

            List {
                Picker(selection: $currencyCode) {
                    ForEach(CurrencyPreference.availableCodes, id: \.self) { code in
                        HStack {
                            Text(CurrencyPreference.displayName(for: code))
                            Spacer()
                            Text(verbatim: code)
                                .foregroundStyle(.secondary)
                        }
                        .tag(code)
                    }
                } label: {
                    Text(L10n.Preferences.currency)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .hapticFeedback(.selection, trigger: currencyCode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared || reduceMotion ? 0 : 15)
        .animation(.easeOut(duration: 0.6), value: isAppeared)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    @Previewable @State var currencyCode = CurrencyPreference.defaultCode
    ZStack {
        OnboardingGlowBackground()
        CurrencyView(currencyCode: $currencyCode)
            .padding(.top, 16)
    }
}
