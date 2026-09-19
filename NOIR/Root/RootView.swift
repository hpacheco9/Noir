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
        _expenseViewModel = State(initialValue: ExpenseViewModel(model: NOIRApp.sharedModelContainer))
    }

    var body: some View {
        CoordinatorView {
            ContentView()
        }
        .environmentObject(Coordinator())
        .environment(expenseViewModel)
        .environment(mainViewModel)
        .tabItem{
            Label("Home", systemImage: "house")
        }
    }
}

#Preview {
    RootView(mainViewModel: MainViewModel(model: NOIRApp.sharedModelContainer))
        .modelContainer(for: Expense.self, inMemory: true)
}
