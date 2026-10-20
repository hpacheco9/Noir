//
//  AddExpenseView.swift
//  NOIR
//

import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel = ExpenseViewModel()
    @State private var saveError: String?

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            ExpenseFormFields(form: $viewModel.form, categories: viewModel.categories)
        }
        .task {
            await viewModel.loadCategories()
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            Task { await viewModel.loadCategories() }
        }
        .navigationTitle(Text(L10n.AddExpenseView.createTitle))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(L10n.AddExpenseView.saveErrorTitle), isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? String(localized: L10n.Shared.unexpectedError))
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
        AddExpenseView()
    }
    .environmentObject(Coordinator())
}
