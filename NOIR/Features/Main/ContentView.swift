//
//  ContentView.swift
//  NOIR
//

import StoreKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: Coordinator
    @AppStorage("home.period") private var selectedPeriod: SpendingPeriod = .day
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @Environment(MainViewModel.self) private var viewModel

    @State private var expensePendingDeletion: ExpenseDTO?

    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var reviewTask: Task<Void, Never>?
    @State private var hasCheckedReviewOnLaunch = false

    var body: some View {
        List {
            expenseListContent
        }
        .task {
            viewModel.adoptPeriod(selectedPeriod)
            await viewModel.fetchData()
        }
        .listStyle(.insetGrouped)
        .onChange(of: router.sheet == nil) { _, isClosed in
            if isClosed {
                scheduleReviewRequestIfEligible(after: .seconds(2))
            } else {
                cancelReviewRequest()
            }
        }
        .onAppear {
            guard !hasCheckedReviewOnLaunch else { return }
            hasCheckedReviewOnLaunch = true
            scheduleReviewRequestIfEligible(after: .seconds(3))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scheduleReviewRequestIfEligible(after: .seconds(3))
            } else {
                cancelReviewRequest()
            }
        }
        .onDisappear { cancelReviewRequest() }
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
                ProfileAvatarButton()
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
        case .failed:
            failedSection
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
                            router.present(MainRoutes.editExpense(expense), mode: .percentage(0.90))
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

    private var failedSection: some View {
        Section {
            VStack(spacing: 12) {
                UnavailableView(
                    L10n.Dashboard.errorTitle,
                    systemImage: AssetName.System.warning,
                    description: L10n.Dashboard.errorDescription
                )

                Button(String(localized: L10n.Dashboard.retry)) {
                    Task { await viewModel.fetchData() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 50)
        }
    }

    // MARK: - Review prompt
    /// Runs at a natural break, never inside the Save action: when a sheet on Home has fully closed, or when the app
    /// opens or comes back to the front. Waits `delay`, then re-checks that nothing is presented and the app is still
    /// active before asking.
    private func scheduleReviewRequestIfEligible(after delay: Duration) {
        cancelReviewRequest()
        let store = ReviewPromptStore()
        let version = AppVersion.current()
        guard store.shouldRequestReview(currentVersion: version) else { return }

        reviewTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled,
                  router.sheet == nil, router.fullScreen == nil,
                  scenePhase == .active,
                  store.shouldRequestReview(currentVersion: version)
            else { return }
            store.markPrompted(version: version)
            requestReview()
        }
    }

    private func cancelReviewRequest() {
        reviewTask?.cancel()
        reviewTask = nil
    }

    // MARK: - Toolbar
    private var periodFilterMenu: some View {
        PeriodMenu(selection: Binding(
            get: { selectedPeriod },
            set: { period in
                withAnimation {
                    selectedPeriod = period
                    viewModel.selectPeriod(period)
                }
            }
        ))
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
