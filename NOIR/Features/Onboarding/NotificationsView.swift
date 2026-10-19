//
//  NotificationsView.swift
//  NOIR
//

import SwiftUI

struct NotificationsView: View {
    @State private var isAppeared = false
    @State private var viewportHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.Onboarding.notificationsTitle)
                        .font(.system(size: titleSize, weight: .bold))
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.Onboarding.notificationsSubtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 32)
                NotificationPanelDemo()
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: viewportHeight, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            viewportHeight = height
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared || reduceMotion ? 0 : 15)
        .animation(.easeOut(duration: 0.6), value: isAppeared)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    ZStack {
        OnboardingGlowBackground()
        NotificationsView()
            .padding(.horizontal, 24)
            .padding(.top, 16)
    }
}
