//
//  EditExpenseView.swift
//  NOIR
//

import SwiftUI

struct EditExpenseView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: EditExpenseViewModel
    @State private var saveError: String?
    @State private var isDeleteConfirmationPresented = false

    init(expense: ExpenseDTO) {
        _viewModel = State(initialValue: EditExpenseViewModel(expense: expense))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            ExpenseFormFields(form: $viewModel.form, categories: viewModel.categories, cards: viewModel.cards)

            Section {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: AssetName.System.delete)
                        Text(L10n.Shared.delete)
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task {
            await viewModel.loadCategories()
            await viewModel.loadCards()
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            Task { await viewModel.loadCategories() }
        }
        .navigationTitle(Text(L10n.AddExpenseView.editTitle))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(L10n.AddExpenseView.saveErrorTitle), isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? String(localized: L10n.Shared.unexpectedError))
        }
        .alert(Text(L10n.ExpenseDeletion.title), isPresented: $isDeleteConfirmationPresented) {
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Shared.delete), role: .destructive) {
                Task {
                    do {
                        if try await viewModel.delete() {
                            coordinator.dismiss()
                        }
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(L10n.ExpenseDeletion.message)
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
