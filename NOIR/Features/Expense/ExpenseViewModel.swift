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
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    private(set) var cards: [String] = []
    private(set) var isSaving = false

    var canSave: Bool { form.canSave }

    let repository: ExpenseRepositoryProvider
    private let reviewPrompt: ReviewPromptStore

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
        NotificationCenter.default.post(name: .expensesDidChange, object: self)
        return true
    }

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

    func loadCards() async {
        do {
            cards = try await repository.perform { try await $0.fetchCards() }
            if form.card.isEmpty, let mostUsed = cards.first { form.card = mostUsed }
        } catch {
            print("Failed to load cards: \(error)")
        }
    }
}
