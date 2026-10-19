//
//  ExpenseViewModelSaveTests.swift
//  NOIRTests
//

import Testing
import SwiftData
@testable import NOIR

struct ExpenseViewModelSaveTests {
    /// Only the "nothing to save" path: a real save writes the overview memo to the app's UserDefaults.
    @Test func saveWithoutValidInputReportsNothingSaved() async throws {
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = ExpenseViewModel(model: container)
        #expect(viewModel.canSave == false)
        #expect(try await viewModel.save() == false)
        #expect(viewModel.isSaving == false)
    }
}
