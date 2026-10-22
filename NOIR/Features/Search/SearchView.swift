import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: SearchViewModel
    
    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    @State private var expensePendingDeletion: ExpenseDTO?
    
    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.86),
            value: resultIDs
        )
        .searchable(
            text: $viewModel.query,
            placement: .automatic,
            prompt: Text(L10n.SearchView.prompt)
        )
        .task {
            await viewModel.search(viewModel.query)
        }
        .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { _ in
            Task { await viewModel.search(viewModel.query) }
        }
        .alert(Text(L10n.SearchView.errorTitle), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileAvatarButton()
            }
        }
        .navigationTitle(L10n.SearchView.title)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sections.isEmpty {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        } else if viewModel.sections.isEmpty {
            Section {
                UnavailableView(
                    viewModel.query.isEmpty
                        ? String(localized: L10n.SearchView.emptyTitle)
                        : "No expenses found",
                    systemImage: AssetName.System.search,
                    description: viewModel.query.isEmpty
                        ? String(localized: L10n.SearchView.emptyDescription)
                        : "Try a different expense name."
                )
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.top, 50)
            }
        } else {
            ForEach(viewModel.sections) { section in
                Section(sectionTitle(for: section.date)) {
                    ForEach(section.expenses) { expense in
                        row(for: expense)
                    }
                }
            }
        }
    }

    private func row(for expense: ExpenseDTO) -> some View {
        ExpenseRow(expense: expense) {
            coordinator.present(MainRoutes.editExpense(expense), mode: .percentage(0.90))
            Haptics.play(.tap)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                expensePendingDeletion = expense
            } label: {
                Image(systemName: AssetName.System.delete)
            }
            .accessibilityLabel(Text(L10n.Shared.delete))
            .tint(.red)
        }
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 12)),
                removal: .opacity.combined(with: .scale(scale: 0.96))
            )
        )
        .onAppear {
            Task {
                await viewModel.loadMoreIfNeeded(after: expense)
            }
        }
    }

    private var resultIDs: [PersistentIdentifier] {
        viewModel.sections.flatMap { $0.expenses.map(\.id) }
    }

    private func sectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

#Preview {
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(model: NOIRApp.sharedModelContainer)
        )
    }
    .environmentObject(Coordinator())
}
