//
//  UserNameView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct UserNameView: View {
    @Binding var name: String
    @State private var isAppeared: Bool = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Same header as the other steps.
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Onboarding.nameTitle)
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)

                Text(L10n.Onboarding.nameSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared || reduceMotion ? 0 : 15)
            .animation(.easeOut(duration: 0.6), value: isAppeared)

            Spacer(minLength: 32)

            // The greeting and the field sit centred in the space under the header. Stacked rather than side by
            // side, so a long name scrolls inside the field instead of running off the screen.
            VStack(spacing: 4) {
                Text(L10n.Onboarding.nameGreeting)
                    .font(.system(size: 42, weight: .bold))

                TextField(String(localized: L10n.Onboarding.namePlaceholder), text: $name)
                    .font(.system(size: 42, weight: .bold))
                    .multilineTextAlignment(.center)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .tint(.primary)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared || reduceMotion ? 0 : 15)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAppeared)

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    ZStack {
        OnboardingGlowBackground()
        UserNameView(name: .constant(""))
            .padding(.top, 16)
    }
}
