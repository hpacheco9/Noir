//
//  ContentView.swift
//  NOIR
//

import SwiftData
import SwiftUI

enum SearchTransitionID {
    static let button = "search-button"
}

struct ContentView: View {
    @EnvironmentObject private var router: Coordinator
    @State private var selectedPeriod: SpendingPeriod = .day
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @Environment(MainViewModel.self) private var viewModel

    @State private var isSearchPresented = false
    @State private var searchViewModel = SearchViewModel(model: NOIRApp.sharedModelContainer)
    @State private var expensePendingDeletion: ExpenseDTO?
    @Namespace private var searchTransition

    var body: some View {
        List {
            expenseListContent
        }
        .task {
            await viewModel.fetchData()
        }
        .listStyle(.insetGrouped)
        .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { _ in
            Task { await viewModel.fetchData() }
        }
        .alert(
            Text(L10n.ExpenseDeletion.title),
            isPresented: Binding(
                get: { expensePendingDeletion != nil },
                set: { if !$0 { expensePendingDeletion = nil } }
            ),
            presenting: expensePendingDeletion
        ) { expense in
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {
                expensePendingDeletion = nil
            }
            Button(String(localized: L10n.Shared.delete), role: .destructive) {
                expensePendingDeletion = nil
                Task { await viewModel.delete(id: expense.id) }
            }
        } message: { _ in
            Text(L10n.ExpenseDeletion.message)
        }
        .overlay(alignment: .bottomTrailing) {
            addExpenseButton
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                accountButton
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItemGroup(placement: .confirmationAction) {
                searchButton
                periodFilterMenu
            }
        }
    }

    // MARK: - List content

    @ViewBuilder
    private var expenseListContent: some View {
        switch viewModel.state {
        case .empty:
            emptyStateSection
        case .loaded(let expenses):
            loadedSections(for: expenses)
        case .loading:
            loadingSection
        }
    }

    private var emptyStateSection: some View {
        Section {
            ContentUnavailableView {
                Label(String(localized: L10n.MainView.emptyTitle), systemImage: AssetName.System.transactions)
                    .font(.title3.bold())
            } description: {
                Text(L10n.MainView.emptyDescription)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 50)
        }
    }

    @ViewBuilder
    private func loadedSections(for expenses: [ExpenseDTO]) -> some View {
        Section {
            SpendingOverviewView(
                expenses: expenses,
                currencyCode: currencyCode,
                selectedPeriod: $selectedPeriod
            )
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())

        ForEach(viewModel.recentExpenseSections(from: expenses)) { day in
            Section(viewModel.title(for: day.date)) {
                ForEach(day.expenses) { expense in
                    ExpenseRow(
                        expense: expense,
                        action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            expensePendingDeletion = expense
                        } label: {
                            Label(
                                String(localized: L10n.Shared.delete),
                                systemImage: AssetName.System.delete
                            )
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    private var loadingSection: some View {
        Section {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - Toolbar

    private var accountButton: some View {
        Button {
            router.present(MainRoutes.settings(), mode: .large)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                Text("H")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
            }
        }
    }

    private var searchButton: some View {
        Button(action: presentSearch) {
            Image(systemName: "magnifyingglass")
        }
        .matchedTransitionSource(id: SearchTransitionID.button, in: searchTransition)
    }

    private var periodFilterMenu: some View {
        Menu {
            ForEach(SpendingPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    if period == selectedPeriod {
                        Label(period.title, systemImage: AssetName.System.checkmark)
                    } else {
                        Text(period.title)
                    }
                }
            }
        } label: {
            Image(systemName: AssetName.System.filter)
        }
    }

    private var addExpenseButton: some View {
        Button {
            router.present(MainRoutes.addExpense(), mode: .large)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            Image(systemName: AssetName.System.add)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(uiColor: .systemBackground))
                .frame(width: 55, height: 55)
        }
        .clipShape(.circle)
        .tint(.primary)
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Actions

    private func presentSearch() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        router.navigate(to: MainRoutes.search(nameSpace: searchTransition))
    }
}



#Preview {
    CoordinatorView {
        ContentView()
            .modelContainer(for: Expense.self, inMemory: true)
    }
    .environmentObject(Coordinator())
    .environment(MainViewModel(model: NOIRApp.sharedModelContainer))
}
