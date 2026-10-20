//
//  EditExpenseViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// Edit Expense without writing: a real save or delete adjusts Home's overview memos in `UserDefaults.standard`.
@MainActor
struct EditExpenseViewModelTests {
    /// An expense in `category`, resolved through `categories` the way the repository does.
    private func makeExpense(
        amount: Double = 10,
        categoryKey: String = ExpenseCategory.food.rawValue,
        categories: [CategoryInfo] = CategoryInfo.builtIns
    ) -> ExpenseDTO {
        let row = Expense(amount: amount, name: "Coffee", date: .now, category: .other, expenseDescription: "Morning")
        row.categoryRawValue = categoryKey
        return ExpenseDTO(row, categories: Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) }))
    }

    @Test func formIsPrefilledFromTheExpense() {
        let viewModel = EditExpenseViewModel(expense: makeExpense())
        #expect(viewModel.form.amount == 10)
        #expect(viewModel.form.name == "Coffee")
        #expect(viewModel.form.category == ExpenseCategory.food.rawValue)
        #expect(viewModel.form.description == "Morning")
        #expect(viewModel.canSave)
    }

    @Test func amountRoundTripsExactly() {
        let viewModel = EditExpenseViewModel(expense: makeExpense(amount: 19.99))
        #expect(viewModel.form.amount == Decimal(string: "19.99")!)
        #expect(viewModel.form.amountValue == 19.99)
    }

    @Test func invalidFormIsNotSaved() async throws {
        let viewModel = EditExpenseViewModel(expense: makeExpense())
        viewModel.form.name = "  "

        #expect(try await viewModel.save() == false)
        #expect(viewModel.isSaving == false)
    }

    @Test func customCategoryIsAddedToThePicker() {
        let custom = CategoryInfo(custom: CustomCategory(name: "Pets", symbol: "pawprint", colorRawValue: "teal"))
        let viewModel = EditExpenseViewModel(
            expense: makeExpense(categoryKey: custom.key, categories: CategoryInfo.builtIns + [custom])
        )

        #expect(viewModel.form.category == custom.key)
        #expect(viewModel.categories.count == CategoryInfo.builtIns.count + 1)
        #expect(viewModel.categories.last == custom)
    }

    @Test func overriddenBuiltInReplacesThePlainOne() {
        let overridden = CategoryInfo(
            builtIn: .food,
            override: BuiltInCategoryOverride(key: ExpenseCategory.food.rawValue, name: "Groceries", symbol: "cart")
        )
        let viewModel = EditExpenseViewModel(expense: makeExpense(categories: [overridden]))

        let shown = viewModel.categories.filter { $0.key == ExpenseCategory.food.rawValue }
        #expect(shown == [overridden])
        #expect(shown.first?.icon == "cart")
        #expect(viewModel.categories.count == CategoryInfo.builtIns.count)
    }
}
