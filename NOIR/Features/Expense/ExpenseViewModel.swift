//
//  ExpenseViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

/// Add Expense: creates a new expense.
@MainActor
@Observable
final class ExpenseViewModel {

    var form = ExpenseForm()
    /// Choices for the picker. Starts with the plain built-ins until the first `loadCategories()`.
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    /// A save is in flight; the Save button is disabled and a second `save()` is ignored.
    private(set) var isSaving = false

    var canSave: Bool { form.canSave }

    let repository: ExpenseRepositoryProvider
    /// Counts created expenses toward the review prompt (injectable so a test can use an isolated suite).
    private let reviewPrompt: ReviewPromptStore

    /// Inserts the expense. Injectable because the repository's save also adjusts Home's overview memos in
    /// `UserDefaults.standard`, which tests must not touch.
    typealias Saver = @Sendable (ExpenseForm) async throws -> Void
    private let saveExpense: Saver

    init(
        model: ModelContainer = NOIRApp.sharedModelContainer,
        reviewPrompt: ReviewPromptStore = ReviewPromptStore(),
        saver: Saver? = nil
    ) {
        let repository = ExpenseRepositoryProvider(container: model)
        self.repository = repository
        self.reviewPrompt = reviewPrompt
        self.saveExpense = saver ?? { try await repository.save($0, id: nil) }
    }

    /// Returns whether it actually saved (false when there was nothing to save or a save was already running).
    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await saveExpense(form.trimmed)
        reviewPrompt.recordCreatedExpense()
        // `object: self` still reaches every `object: nil` listener; it lets a test tell this post apart.
        NotificationCenter.default.post(name: .expensesDidChange, object: self)
        return true
    }

    /// Refreshes the picker's choices. A selection whose category no longer exists falls back to Other.
    func loadCategories() async {
        let loaded: [CategoryInfo]
        do {
            loaded = try await repository.perform { try await $0.fetchCategories() }
        } catch {
            print("Failed to load categories: \(error)")
            return
        }
        categories = loaded
        if !loaded.contains(where: { $0.key == form.category }) {
            form.category = ExpenseCategory.other.rawValue
        }
    }
}
