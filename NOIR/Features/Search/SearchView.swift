import SwiftUI

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
                                   //coordinator.present(AppRoute.addExpense(expense), mode: .large)
                                }
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(after: expense)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(
            text: $viewModel.query,
            placement: .automatic,
            prompt: Text(L10n.SearchView.prompt)
        )
        .task {
            await viewModel.loadInitialPage()
        }
        .onChange(of: viewModel.query) { _, newQuery in
            viewModel.queryDidChange(newQuery)
        }
        .alert("Search error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar{
            ToolbarItem(placement: .confirmationAction){
                Button {
                    coordinator.pop()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(L10n.SearchView.title)
        .navigationBarTitleDisplayMode(.large)
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
