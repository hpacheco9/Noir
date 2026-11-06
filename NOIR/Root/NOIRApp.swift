//
//  NOIRApp.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct NOIRApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchaseStore: PurchaseStore
    @State private var mainViewModel: MainViewModel

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            CustomCategory.self,
            BuiltInCategoryOverride.self,
            RecurringExpense.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let purchaseStore = PurchaseStore.shared
        if ProAccess.isPaywallEnabled, !RevenueCatConfig.isRunningTests {
            RevenueCatConfig.configure()
            purchaseStore.start()
        }
        _purchaseStore = State(initialValue: purchaseStore)
        _mainViewModel = State(initialValue: MainViewModel(model: Self.sharedModelContainer))
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
        Task { await ExpenseRepositoryProvider(container: Self.sharedModelContainer).retireOtherCategoryOnce() }
    }

    var body: some Scene {
        WindowGroup {
            AppGate(mainViewModel: mainViewModel)
        }
        .modelContainer(Self.sharedModelContainer)
        .environment(purchaseStore)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await purchaseStore.refresh() } }
        }
    }
}
