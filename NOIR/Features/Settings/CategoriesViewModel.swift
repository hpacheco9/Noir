//
//  CategoriesViewModel.swift
//  NOIR
//

import Foundation
import Observation

@MainActor
@Observable
final class CategoriesViewModel {
    private(set) var builtIn: [CategoryInfo] = []
    /// False until the first load finishes, so the list doesn't flash the defaults before overrides apply.
    private(set) var isLoaded = false
    private(set) var custom: [CategoryInfo] = []
    var errorMessage: String?

    private let repository: ExpenseRepositoryProvider

    init(repository: ExpenseRepositoryProvider? = nil) {
        self.repository = repository ?? .init(container: NOIRApp.sharedModelContainer)
    }

    func load() async {
        await load(reportingErrors: true)
    }

    private func load(reportingErrors: Bool) async {
        do {
            let all = try await repository.perform { try await $0.fetchCategories() }
            builtIn = all.filter(\.isBuiltIn)
            custom = all.filter { !$0.isBuiltIn }
        } catch {
            if reportingErrors { errorMessage = String(localized: L10n.Categories.loadError) }
        }
        isLoaded = true
    }

    /// Deletes a custom category; its expenses move to Other.
    func delete(_ category: CategoryInfo) async {
        guard let id = category.customID else { return }
        do {
            let reassigned = try await repository.perform { try await $0.deleteCategory(id: id) }
            custom.removeAll { $0.key == category.key }
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            if reassigned > 0 {
                NotificationCenter.default.post(name: .expensesDidChange, object: nil)
            }
        } catch {
            errorMessage = String(localized: L10n.Categories.deleteError)
            await load(reportingErrors: false)
        }
    }
}
