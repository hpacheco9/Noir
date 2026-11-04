//
//  RecurringExpensesViewModel.swift
//  NOIR
//

import Foundation
import Observation

@MainActor
@Observable
final class RecurringExpensesViewModel {
    private(set) var items: [RecurringExpenseDTO] = []
    private(set) var isLoaded = false
    var errorMessage: String?

    private let repository: ExpenseRepositoryProvider

    init(repository: ExpenseRepositoryProvider? = nil) {
        self.repository = repository ?? .init(container: NOIRApp.sharedModelContainer)
    }

    func load() async {
        do {
            items = try await repository.perform { try await $0.fetchRecurring() }
        } catch {
            errorMessage = String(localized: L10n.Shared.unexpectedError)
        }
        isLoaded = true
    }

    func stopRepeating(_ item: RecurringExpenseDTO) async {
        do {
            try await repository.deleteRecurring(id: item.id)
        } catch RepositoryError.notFound {
            // Already gone: same result.
        } catch {
            errorMessage = String(localized: L10n.Shared.unexpectedError)
            await load()
            return
        }
        items.removeAll { $0.id == item.id }
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
    }
}
