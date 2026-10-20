//
//  ExpenseViewModelSaveTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

/// Add Expense. The insert is injected (the repository's save adjusts Home's overview memos in
/// `UserDefaults.standard`), and the review prompt counts into a throwaway suite.
@MainActor
final class ExpenseViewModelSaveTests {
    private final class Recorder {
        var saved: [ExpenseForm] = []
        var notifications = 0
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

    private func makeViewModel(saver: @escaping ExpenseViewModel.Saver) -> ExpenseViewModel {
        ExpenseViewModel(reviewPrompt: ReviewPromptStore(defaults: defaults), saver: saver)
    }

    /// Counts the `.expensesDidChange` posts `viewModel` makes while `body` runs. Filtered by sender: other suites
    /// run in parallel and post the same notification.
    private func countingNotifications(
        from viewModel: ExpenseViewModel, into recorder: Recorder, _ body: () async throws -> Void
    ) async rethrows {
        let token = NotificationCenter.default.addObserver(
            forName: .expensesDidChange, object: viewModel, queue: nil
        ) { _ in MainActor.assumeIsolated { recorder.notifications += 1 } }  // posted on the main actor
        defer { NotificationCenter.default.removeObserver(token) }
        try await body()
    }

    @Test func saveWithoutValidInputReportsNothingSaved() async throws {
        let recorder = Recorder()
        let viewModel = makeViewModel { form in await MainActor.run { recorder.saved.append(form) } }

        #expect(viewModel.canSave == false)
        #expect(try await viewModel.save() == false)

        viewModel.form.name = "   "
        viewModel.form.amount = 5
        #expect(try await viewModel.save() == false)

        #expect(recorder.saved.isEmpty)
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 0)
    }

    @Test func saveInsertsTrimmedValuesCountsAndNotifies() async throws {
        let recorder = Recorder()
        let viewModel = makeViewModel { form in await MainActor.run { recorder.saved.append(form) } }
        viewModel.form.amount = Decimal(string: "12.5")!
        viewModel.form.name = "  Lunch  "
        viewModel.form.category = ExpenseCategory.food.rawValue
        viewModel.form.description = " with Ana \n"

        var didSave = false
        try await countingNotifications(from: viewModel, into: recorder) {
            didSave = try await viewModel.save()
        }

        #expect(didSave)
        let saved = try #require(recorder.saved.first)
        #expect(recorder.saved.count == 1)
        #expect(saved.amount == Decimal(string: "12.5")!)
        #expect(saved.name == "Lunch")
        #expect(saved.category == ExpenseCategory.food.rawValue)
        #expect(saved.description == "with Ana")
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 1)
        #expect(recorder.notifications == 1)
    }

    @Test func failedSaveThrowsDoesNotCountAndDoesNotNotify() async throws {
        let recorder = Recorder()
        let viewModel = makeViewModel { _ in throw SaveFailed() }
        viewModel.form.amount = 3
        viewModel.form.name = "Coffee"

        await countingNotifications(from: viewModel, into: recorder) {
            await #expect(throws: SaveFailed.self) { try await viewModel.save() }
        }
        #expect(viewModel.isSaving == false)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 0)
        #expect(recorder.notifications == 0)
    }
}
