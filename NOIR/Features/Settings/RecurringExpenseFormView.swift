//
//  RecurringExpenseFormView.swift
//  NOIR
//

import SwiftUI

struct RecurringExpenseFormView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: RecurringExpenseFormViewModel
    @State private var saveError: String?
    @State private var isStopConfirmationPresented = false

    init(recurring: RecurringExpenseDTO?) {
        _viewModel = State(initialValue: RecurringExpenseFormViewModel(editing: recurring))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            ExpenseFormFields(
                form: $viewModel.form,
                categories: viewModel.categories,
                cards: viewModel.cards,
                dateTitle: L10n.Recurring.nextDate,
                showsRepeat: true,
                allowsNeverRepeat: false
            )

            if viewModel.isEditing {
                Section {
                    Button(role: .destructive) {
                        isStopConfirmationPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: AssetName.System.delete)
                            Text(L10n.Recurring.stop)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .task {
            await viewModel.loadCategories()
            await viewModel.loadCards()
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            Task { await viewModel.loadCategories() }
        }
        .navigationTitle(Text(viewModel.isEditing ? L10n.Recurring.editTitle : L10n.Recurring.newTitle))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(L10n.AddExpenseView.saveErrorTitle), isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? String(localized: L10n.Shared.unexpectedError))
        }
        .alert(Text(L10n.Recurring.stopTitle), isPresented: $isStopConfirmationPresented) {
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Recurring.stop), role: .destructive) {
                Task {
                    do {
                        if try await viewModel.stopRepeating() { coordinator.dismiss() }
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(L10n.Recurring.stopMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    coordinator.dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    Task {
                        do {
                            if try await viewModel.save() {
                                Haptics.play(.success)
                                coordinator.dismiss()
                            }
                        } catch {
                            Haptics.play(.error)
                            saveError = error.localizedDescription
                        }
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
    }
}

#Preview {
    CoordinatorView {
        RecurringExpenseFormView(recurring: nil)
    }
    .environmentObject(Coordinator())
}
