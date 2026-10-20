//
//  RootView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var expenseViewModel: ExpenseViewModel
    @State private var dashboardViewModel: DashboardViewModel
    @State private var searchViewModel: SearchViewModel
    @StateObject private var homeCoordinator = Coordinator()
    @StateObject private var dashboardCoordinator = Coordinator()
    @StateObject private var searchCoordinator = Coordinator()
    let mainViewModel: MainViewModel

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        _dashboardViewModel = State(initialValue: DashboardViewModel(model: NOIRApp.sharedModelContainer))
        _searchViewModel = State(initialValue: SearchViewModel(model: NOIRApp.sharedModelContainer))
        _expenseViewModel = State(
            initialValue: ExpenseViewModel(
                model: NOIRApp.sharedModelContainer
            )
        )
    }

    var body: some View {
        TabView {
            CoordinatorView {
                ContentView()
            }
            .environmentObject(homeCoordinator)
            .environment(expenseViewModel)
            .environment(mainViewModel)
            .tabItem {
                Label {
                    Text(L10n.Tab.home)
                } icon: {
                    Image(systemName: AssetName.System.home)
                }
                .environment(\.symbolVariants, .none)
            }

            CoordinatorView {
                DashboardView(viewModel: dashboardViewModel)
            }
            .environmentObject(dashboardCoordinator)
            .tabItem {
                Label {
                    Text(L10n.Tab.dashboard)
                } icon: {
                    Image(systemName: AssetName.System.dashboard)
                }
                .environment(\.symbolVariants, .none)
            }

            CoordinatorView {
                SearchView(viewModel: searchViewModel)
            }
            .environmentObject(searchCoordinator)
            .environment(expenseViewModel)
            .tabItem {
                Label {
                    Text(L10n.Tab.search)
                } icon: {
                    Image(systemName: AssetName.System.search)
                }
                //   .environment(\.symbolVariants, .none)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    RootView(mainViewModel: MainViewModel(model: NOIRApp.sharedModelContainer))
        .modelContainer(for: [Expense.self, CustomCategory.self, BuiltInCategoryOverride.self], inMemory: true)
}
