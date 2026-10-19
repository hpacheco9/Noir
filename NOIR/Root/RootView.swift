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
    let mainViewModel: MainViewModel

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
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
            .environmentObject(Coordinator())
            .environment(expenseViewModel)
            .environment(mainViewModel)
            .tabItem {
                Label("Home", systemImage: "text.rectangle.page")
                  .environment(\.symbolVariants, .none)
            }

            CoordinatorView {
                Text("Calendar view")
            }
            .environmentObject(Coordinator())
            .tabItem {
                Label("Calendar", systemImage: "calendar")
                  .environment(\.symbolVariants, .none)
            }

            CoordinatorView {
                SearchView(
                    viewModel: SearchViewModel(
                        model: NOIRApp.sharedModelContainer
                    )
                )
            }
            .environmentObject(Coordinator())
            .environment(expenseViewModel)
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
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
