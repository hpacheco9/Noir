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
    @State private var isCompleting = false
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
                }
                
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 4) {
                Button {
                    if viewModel.isLastStep {
                        switch viewModel.notificationPermission {
                        case .undetermined: finish(requestingNotifications: true)
                        case .allowed: finish(requestingNotifications: false)
                        case .denied:
                            // Stay on the step; coming back re-reads the permission (scenePhase below).
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    } else {
                        viewModel.advance()
                    }
                } label: {
                    Group {
                        if isCompleting {
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
                .disabled(!viewModel.canAdvance || isCompleting)
                .accessibilityLabel(String(localized: isCompleting ? L10n.Onboarding.finishing : viewModel.primaryActionTitle))

                if viewModel.step == .notifications {
                    Button {
                        finish(requestingNotifications: false)
                    } label: {
                        Text(L10n.Onboarding.notNow)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 26)
                    .disabled(isCompleting)
                    .opacity(isCompleting ? 0.4 : 1)
                }
            }
            .padding(.vertical, 5)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .task { await viewModel.refreshNotificationPermission() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refreshNotificationPermission() } }
        }
        .animation(.snappy, value: viewModel.step)
        .animation(.snappy, value: viewModel.notificationPermission)
        .animation(.snappy, value: isCompleting)
    }

    private func finish(requestingNotifications: Bool) {
        guard !isCompleting else { return }
        isCompleting = true

        Task {
            await viewModel.complete(requestingNotifications: requestingNotifications)
            onComplete()
        }
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
