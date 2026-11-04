//
//  RecurringExpensesView.swift
//  NOIR
//

import SwiftUI

struct RecurringExpensesView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel = RecurringExpensesViewModel()
    @State private var pendingStop: RecurringExpenseDTO?

    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                Button {
                    coordinator.present(SettingsRoutes.editRecurring(item), mode: .large)
                } label: {
                    RecurringExpenseRow(recurring: item)
                }
                .tint(.primary)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingStop = item
                    } label: {
                        Image(systemName: AssetName.System.delete)
                    }
                    .accessibilityLabel(Text(L10n.Recurring.stop))
                }
            }
        }
        .overlay {
            if viewModel.isLoaded && viewModel.items.isEmpty {
                UnavailableView(
                    L10n.Recurring.emptyTitle,
                    systemImage: AssetName.System.recurring,
                    description: L10n.Recurring.emptyDescription
                )
            }
        }
        .navigationTitle(Text(L10n.Recurring.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: L10n.Recurring.newTitle), systemImage: AssetName.System.add) {
                    coordinator.present(SettingsRoutes.newRecurring(), mode: .large)
                }
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .recurringDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .alert(
            Text(L10n.Recurring.stopTitle),
            isPresented: .init(
                get: { pendingStop != nil },
                set: { if !$0 { pendingStop = nil } }
            ),
            presenting: pendingStop
        ) { item in
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Recurring.stop), role: .destructive) {
                Task { await viewModel.stopRepeating(item) }
            }
        } message: { _ in
            Text(L10n.Recurring.stopMessage)
        }
        .alert(Text(L10n.Categories.errorTitle), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? String(localized: L10n.Shared.unexpectedError))
        }
    }
}

private struct RecurringExpenseRow: View {
    let recurring: RecurringExpenseDTO
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: recurring.categoryInfo.icon)
                .font(.headline)
                .foregroundStyle(recurring.categoryInfo.color)
                .frame(width: 40, height: 40)
                .background(recurring.categoryInfo.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(recurring.name)
                    .lineLimit(1)
                    .font(.headline)

                Text(L10n.Recurring.rowDetail(
                    frequency: String(localized: recurring.frequency.title),
                    next: recurring.nextDueDate.formatted(.dateTime.day().month(.abbreviated))
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(verbatim: CurrencyPreference.string(for: recurring.amount, code: currencyCode))
                .font(.headline)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CoordinatorView {
        RecurringExpensesView()
    }
    .environmentObject(Coordinator())
}
