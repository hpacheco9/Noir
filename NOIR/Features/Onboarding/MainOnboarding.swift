//
//  MainOnboarding.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct MainOnboarding: View {
    var onComplete: () -> Void
    @State private var viewModel = OnboardingViewModel()
    @State private var isRequesting = false
    @State private var hasFinished = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            OnboardingGlowBackground()
            VStack {
                switch viewModel.step {
                    case .welcome:
                        GetStartedView()
                    case .name:
                        UserNameView(name: $viewModel.name)
                    case .currency:
                        CurrencyView(currencyCode: $viewModel.currencyCode)
                    case .notifications:
                        NotificationsView()
                    case .paywall:
                        PaywallView(onClose: finish)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            if viewModel.step != .paywall {
                controls
            }
        }
        .task { await viewModel.refreshNotificationPermission() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refreshNotificationPermission() } }
        }
        .animation(.snappy, value: viewModel.step)
        .animation(.snappy, value: viewModel.notificationPermission)
        .animation(.snappy, value: isRequesting)
    }

    private var controls: some View {
        VStack(spacing: 4) {
            Button {
                if viewModel.step == .notifications {
                    switch viewModel.notificationPermission {
                    case .undetermined: leaveNotifications(requesting: true)
                    case .allowed: leaveNotifications(requesting: false)
                    case .denied:
                        // Stay on the step; coming back re-reads the permission (scenePhase above).
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                } else {
                    viewModel.advance()
                }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text(viewModel.primaryActionTitle)
                            .font(.body.weight(.medium))
                    }
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .tint(.primary)
            .padding(.horizontal, 26)
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.canAdvance || isRequesting)
            .accessibilityLabel(String(localized: viewModel.primaryActionTitle))

            if viewModel.step == .notifications {
                Button {
                    leaveNotifications(requesting: false)
                } label: {
                    Text(L10n.Onboarding.notNow)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)
                .disabled(isRequesting)
                .opacity(isRequesting ? 0.4 : 1)
            }
        }
        .padding(.vertical, 5)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func leaveNotifications(requesting: Bool) {
        guard !isRequesting else { return }
        isRequesting = true

        Task {
            await viewModel.finishNotificationsStep(requesting: requesting)
            isRequesting = false
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        viewModel.persist()
        onComplete()
    }
}

#Preview("Light") {
    NavigationStack {
        MainOnboarding(onComplete: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        MainOnboarding(onComplete: {})
    }
    .preferredColorScheme(.dark)
}
