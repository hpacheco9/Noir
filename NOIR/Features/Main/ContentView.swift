//
//  ContentView.swift
//  NOIR
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: Coordinator
    @State private var selectedPeriod: SpendingPeriod = .day
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @Environment(MainViewModel.self) private var viewModel

    @State private var expensePendingDeletion: ExpenseDTO?

    var body: some View {
        List {
            expenseListContent
        }
        .task {
            viewModel.adoptPeriod(selectedPeriod)
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
                withAnimation {
                    expensePendingDeletion = nil
                    Task { await viewModel.delete(id: expense.id) }
                }
            }
        } message: { _ in
            Text(L10n.ExpenseDeletion.message)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                accountButton
            }

            ToolbarItemGroup(placement: .confirmationAction) {
                addExpenseButton
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
        case .loaded(let snapshot):
            loadedSections(for: snapshot)
        case .loading:
            loadingSection
        }
    }

    private var emptyStateSection: some View {
        Section {
            UnavailableView(
                L10n.MainView.emptyTitle,
                systemImage: AssetName.System.transactions,
                description: L10n.MainView.emptyDescription
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 50)
        }
    }

    @ViewBuilder
    private func loadedSections(for snapshot: OverviewSnapshot) -> some View {
        Section {
            SpendingOverviewView(
                snapshot: snapshot,
                currencyCode: currencyCode,
                selectedPeriod: $selectedPeriod
            )
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())

        let latestExpenses = snapshot.latest
        if !latestExpenses.isEmpty {
            Section {
                ForEach(latestExpenses) { expense in
                    ExpenseRow(
                        expense: expense,
                        action: {
                            router.present(MainRoutes.editExpense(expense: expense), mode: .percentage(0.90))
                            Haptics.play(.tap)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            expensePendingDeletion = expense
                        } label: {
                            Image(systemName: AssetName.System.delete)
                        }
                        .tint(.red)
                    }
                }
            } header: {
                Text(L10n.MainView.latestTransactions)
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
        ZStack {
            Circle()
                .fill(Color.gray)
                
            Text("H")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.white)
        }
        .onTapGesture {
            router.present(MainRoutes.settings(), mode: .large)
        }
        .frame(width: 36, height: 36)
    }

    private var periodFilterMenu: some View {
        Menu {
            ForEach(SpendingPeriod.allCases) { period in
                Button {
                    withAnimation {
                        selectedPeriod = period
                        viewModel.selectPeriod(period)
                    }
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
            router.present(MainRoutes.addExpense(), mode: .percentage(0.75))
            Haptics.play(.tap)
        } label: {
            Image(systemName: AssetName.System.add)
        }
    }
    
    
}

#Preview {
    CoordinatorView {
        ContentView()
            .modelContainer(for: [Expense.self, CustomCategory.self, BuiltInCategoryOverride.self], inMemory: true)
    }
    .environmentObject(Coordinator())
    .environment(MainViewModel(model: NOIRApp.sharedModelContainer))
}
