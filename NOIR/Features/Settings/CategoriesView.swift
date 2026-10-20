//
//  CategoriesView.swift
//  NOIR
//

import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel = CategoriesViewModel()
    @State private var pendingDeletion: CategoryInfo?

    var body: some View {
        List {
            if viewModel.isLoaded {
                Section(String(localized: L10n.Categories.builtInSection)) {
                    ForEach(viewModel.builtIn) { category in
                        editableRow(category)
                    }
                }

                Section(String(localized: L10n.Categories.customSection)) {
                    if viewModel.custom.isEmpty {
                        Text(L10n.Categories.customEmpty)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.custom) { category in
                            editableRow(category)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = category
                                } label: {
                                    Image(systemName: AssetName.System.delete)
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(L10n.Categories.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: L10n.Categories.add), systemImage: AssetName.System.add) {
                    coordinator.present(SettingsRoutes.newCategory(), mode: .large)
                }
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .alert(
            Text(L10n.Categories.deleteTitle),
            isPresented: .init(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { category in
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Shared.delete), role: .destructive) {
                Task { await viewModel.delete(category) }
            }
        } message: { _ in
            Text(L10n.Categories.deleteMessage(otherTitle: viewModel.otherTitle))
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

private extension CategoriesView {
    /// A row that opens the edit sheet (built-ins and custom categories alike).
    func editableRow(_ category: CategoryInfo) -> some View {
        Button {
            coordinator.present(SettingsRoutes.editCategory(category), mode: .large)
        } label: {
            HStack {
                CategoryRow(category: category)
                Spacer()
                Image(systemName: AssetName.System.disclosure)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}

private struct CategoryRow: View {
    let category: CategoryInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.headline)
                .foregroundStyle(category.color)
                .frame(width: 40, height: 40)
                .background(category.color.opacity(0.12), in: Circle())

            Text(category.title)
                .font(.body)
                .lineLimit(1)
        }
    }
}

#Preview {
    CoordinatorView {
        CategoriesView()
    }
    .environmentObject(Coordinator())
}
