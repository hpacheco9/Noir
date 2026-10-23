//
//  RootView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var dashboardViewModel: DashboardViewModel
    @State private var searchViewModel: SearchViewModel
    @StateObject private var homeCoordinator = Coordinator()
    @StateObject private var dashboardCoordinator = Coordinator()
    @StateObject private var searchCoordinator = Coordinator()
    @State private var selectedTab = RootTab.home
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @Environment(\.scenePhase) private var scenePhase
    let mainViewModel: MainViewModel
    private let addExpenseRequest = AddExpenseRequest.shared

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        _dashboardViewModel = State(initialValue: DashboardViewModel(model: NOIRApp.sharedModelContainer))
        _searchViewModel = State(initialValue: SearchViewModel(model: NOIRApp.sharedModelContainer))
    }

    private var searchRole: TabRole {
        if #available(iOS 27, *) { .prominent } else { .search }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: RootTab.home) {
                CoordinatorView {
                    ContentView()
                }
                .environmentObject(homeCoordinator)
                .environment(mainViewModel)
            } label: {
                Label {
                    Text(L10n.Tab.home)
                } icon: {
                    Image(systemName: AssetName.System.home)
                }
                .environment(\.symbolVariants, .none)
            }

            Tab(value: RootTab.dashboard) {
                CoordinatorView {
                    DashboardView(viewModel: dashboardViewModel)
                }
                .environmentObject(dashboardCoordinator)
            } label: {
                Label {
                    Text(L10n.Tab.dashboard)
                } icon: {
                    Image(systemName: AssetName.System.dashboard)
                }
                .environment(\.symbolVariants, .none)
            }

            Tab(value: RootTab.search, role: .search) {
                CoordinatorView {
                    SearchView(viewModel: searchViewModel)
                }
                .environmentObject(searchCoordinator)
            } label: {
                Label {
                    Text(L10n.Tab.search)
                } icon: {
                    Image(systemName: AssetName.System.search)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewSearchActivation(.searchTabSelection)
        .tint(.primary)
        .onChange(of: addExpenseRequest.isPending, initial: true) { _, isPending in
            if isPending { openAddExpense() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await WidgetSnapshotPublisher.publish() } }
        }
        .onChange(of: currencyCode) {
            Task { await WidgetSnapshotPublisher.publish() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { _ in
            Task { await WidgetSnapshotPublisher.publish() }
        }
    }
}

private extension RootView {
    // Only the selected tab can have a sheet up, so Add Expense goes on its coordinator.
    func openAddExpense() {
        guard addExpenseRequest.consume() else { return }
        switch selectedTab {
        case .home: homeCoordinator.presentAddExpenseIfNeeded()
        case .dashboard: dashboardCoordinator.presentAddExpenseIfNeeded()
        case .search: searchCoordinator.presentAddExpenseIfNeeded()
        }
    }
}

#Preview {
    RootView(mainViewModel: MainViewModel(model: NOIRApp.sharedModelContainer))
        .modelContainer(for: [Expense.self, CustomCategory.self, BuiltInCategoryOverride.self], inMemory: true)
}
