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
    @State private var saveError: String?
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
                    case .budget:
                        BudgetView(budget: $viewModel.budget)
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
        .alert("Unable to save your expense", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func finish(requestingNotifications: Bool) {
        guard !isCompleting else { return }
        isCompleting = true

        Task {
            do {
                try await viewModel.complete(requestingNotifications: requestingNotifications)
                onComplete()
            } catch {
                saveError = error.localizedDescription
                isCompleting = false
            }
        }
    }
}

struct OnboardingGlowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var glowColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var baseGlowOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.20
    }

    private var glowFalloff: Double {
        colorScheme == .dark ? 0.24 : 0.40
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height)

            ZStack {
                Color(uiColor: .systemBackground)

                glow(
                    at: UnitPoint(x: 0.82, y: 0.08),
                    radius: radius * 0.34,
                    opacity: baseGlowOpacity
                )

                glow(
                    at: UnitPoint(x: 0.12, y: 0.22),
                    radius: radius * 0.28,
                    opacity: baseGlowOpacity * 0.45
                )

                glow(
                    at: UnitPoint(x: 0.68, y: 0.93),
                    radius: radius * 0.42,
                    opacity: baseGlowOpacity * 0.72
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func glow(at center: UnitPoint, radius: CGFloat, opacity: Double) -> some View {
        RadialGradient(
            colors: [
                glowColor.opacity(opacity),
                glowColor.opacity(opacity * glowFalloff),
                .clear
            ],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
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
