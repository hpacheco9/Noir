import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: SearchViewModel
    
    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                ProgressView()
            } else if viewModel.sections.isEmpty {
                UnavailableView(
                    viewModel.query.isEmpty
                        ? String(localized: L10n.SearchView.emptyTitle)
                        : "No expenses found",
                    systemImage: AssetName.System.search,
                    description: viewModel.query.isEmpty
                        ? String(localized: L10n.SearchView.emptyDescription)
                        : "Try a different expense name."
                )
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(sectionTitle(for: section.date)) {
                            ForEach(section.expenses) { expense in
                                ExpenseRow(expense: expense) {
                                    coordinator.present(MainRoutes.editExpense(expense: expense), mode: .percentage(0.75))
                                    Haptics.play(.tap)
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
                        }
                    }
                }
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.86),
                    value: resultIDs
                )
                .listStyle(.insetGrouped)
            }
        }
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(L10n.SearchView.prompt)
        )
        .task {
            await viewModel.search(viewModel.query)
        }
        .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { _ in
            Task { await viewModel.search(viewModel.query) }
        }
        // Edits and category deletes happen in sheets over this list. Reload once more when the sheet is gone, so
        // the result is applied while the list is on screen.
        .onChange(of: coordinator.sheet == nil) { _, isSheetGone in
            guard isSheetGone else { return }
            Task { await viewModel.search(viewModel.query) }
        }
        .alert("Search error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction){
                ProfileAvatarButton()
            }
        }
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationTitle(L10n.SearchView.title)
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
