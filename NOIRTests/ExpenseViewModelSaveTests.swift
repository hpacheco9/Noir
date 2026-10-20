//
//  ExpenseViewModelSaveTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// Add Expense. The insert is injected (the repository's save adjusts Home's overview memos in
/// `UserDefaults.standard`), and the review prompt counts into a throwaway suite.
@MainActor
final class ExpenseViewModelSaveTests {
    private final class Recorder {
        var saved: [ExpenseForm] = []
    }

    private struct SaveFailed: Error {}

    private let suiteName = "ExpenseViewModelSaveTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeViewModel(saver: @escaping ExpenseViewModel.Saver) throws -> ExpenseViewModel {
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ExpenseViewModel(model: container, reviewPrompt: ReviewPromptStore(defaults: defaults), saver: saver)
    }

    @Test func saveWithoutValidInputReportsNothingSaved() async throws {
        let recorder = Recorder()
        let viewModel = try makeViewModel { form in await MainActor.run { recorder.saved.append(form) } }

        #expect(viewModel.canSave == false)
        #expect(try await viewModel.save() == false)

        viewModel.form.name = "   "
        viewModel.form.amount = 5
        #expect(try await viewModel.save() == false)

        #expect(recorder.saved.isEmpty)
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 0)
    }

    @Test func saveInsertsTrimmedValuesAndCountsTowardTheReviewPrompt() async throws {
        let recorder = Recorder()
        let viewModel = try makeViewModel { form in await MainActor.run { recorder.saved.append(form) } }
        viewModel.form.amount = Decimal(string: "12.5")!
        viewModel.form.name = "  Lunch  "
        viewModel.form.category = ExpenseCategory.food.rawValue
        viewModel.form.description = " with Ana \n"

        #expect(try await viewModel.save() == true)

        let saved = try #require(recorder.saved.first)
        #expect(recorder.saved.count == 1)
        #expect(saved.amount == Decimal(string: "12.5")!)
        #expect(saved.name == "Lunch")
        #expect(saved.category == ExpenseCategory.food.rawValue)
        #expect(saved.description == "with Ana")
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 1)
    }

    @Test func failedSaveThrowsAndDoesNotCount() async throws {
        let viewModel = try makeViewModel { _ in throw SaveFailed() }
        viewModel.form.amount = 3
        viewModel.form.name = "Coffee"

        await #expect(throws: SaveFailed.self) { try await viewModel.save() }
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 0)
    }
}
