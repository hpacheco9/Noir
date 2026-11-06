//
//  AppGate.swift
//  NOIR
//

import SwiftUI

struct AppGate: View {
    let mainViewModel: MainViewModel

    @AppStorage(OnboardingStorage.hasCompletedKey) private var hasCompletedOnboarding = false
    @Environment(PurchaseStore.self) private var purchaseStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var accessTimedOut = false
    @State private var isAppLatched = false
    private let addExpenseRequest = AddExpenseRequest.shared

    private var screen: RootScreen {
        RootScreen.resolve(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isAccessKnown: purchaseStore.isAccessKnown,
            hasAccess: purchaseStore.hasAccess,
            accessTimedOut: accessTimedOut,
            isAppLatched: isAppLatched
        )
    }

    var body: some View {
        Group {
            switch screen {
            case .onboarding:
                NavigationStack {
                    MainOnboarding(onComplete: {
                        AddExpenseRequest.shared.cancel() // a control tap during onboarding must not open a sheet later
                        hasCompletedOnboarding = true
                    })
                }
            case .loading:
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                    .overlay { ProgressView() }
            case .paywall:
                PaywallView()
                    .tint(.primary)
            case .app:
                RootView(mainViewModel: mainViewModel)
            }
        }
        .onChange(of: screen, initial: true) { _, screen in
            if screen == .app { isAppLatched = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { isAppLatched = false }
        }
        .onChange(of: screen.discardsAddExpenseRequest && addExpenseRequest.isPending, initial: true) { _, discard in
            if discard { addExpenseRequest.cancel() }
        }
        .task(id: purchaseStore.isAccessKnown) {
            guard !purchaseStore.isAccessKnown else { return }
            try? await Task.sleep(for: RootScreen.accessTimeout)
            if !Task.isCancelled { accessTimedOut = true }
        }
    }
}
