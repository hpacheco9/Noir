//
//  SearchViewModelDeleteTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// Swipe-to-delete in Search. Rows are read from an in-memory store; the delete itself is injected, because the
/// repository's delete adjusts Home's overview memos in `UserDefaults.standard`.
@MainActor
struct SearchViewModelDeleteTests {
    private final class Recorder {
        var deletedIDs: [PersistentIdentifier] = []
        var notifications = 0
    }

    private struct DeleteFailed: Error {}

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let today = Date.now
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        context.insert(Expense(amount: 10, name: "Coffee", date: today, category: .food))
        context.insert(Expense(amount: 20, name: "Taxi", date: lastWeek, category: .transport))
        try context.save()
        return container
    }

    private func names(_ viewModel: SearchViewModel) -> [String] {
        viewModel.sections.flatMap { $0.expenses.map(\.name) }
    }

    /// Counts the `.expensesDidChange` posts `viewModel` makes while `body` runs. Filtered by sender: other suites
    /// run in parallel and post the same notification.
    private func countingNotifications(
        from viewModel: SearchViewModel, into recorder: Recorder, _ body: () async -> Void
    ) async {
        let token = NotificationCenter.default.addObserver(
            forName: .expensesDidChange, object: viewModel, queue: nil
        ) { _ in MainActor.assumeIsolated { recorder.notifications += 1 } }  // posted on the main actor
        defer { NotificationCenter.default.removeObserver(token) }
        await body()
    }

    @Test func deleteRemovesTheRowAndItsEmptyDayAndNotifies() async throws {
        let recorder = Recorder()
        let viewModel = SearchViewModel(model: try makeContainer()) { id in
            await MainActor.run { recorder.deletedIDs.append(id) }
        }
        await viewModel.search("")
        #expect(names(viewModel) == ["Coffee", "Taxi"])
        #expect(viewModel.sections.count == 2)

        let taxi = try #require(viewModel.sections.flatMap(\.expenses).first { $0.name == "Taxi" })
        await countingNotifications(from: viewModel, into: recorder) {
            await viewModel.delete(id: taxi.id)
        }

        #expect(recorder.deletedIDs == [taxi.id])
        #expect(names(viewModel) == ["Coffee"])
        // Taxi was the only row of its day, so that day's section is gone too.
        #expect(viewModel.sections.count == 1)
        #expect(recorder.notifications == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failedDeleteBringsTheRowBackAndReportsTheError() async throws {
        let recorder = Recorder()
        let viewModel = SearchViewModel(model: try makeContainer()) { _ in
            throw DeleteFailed()
        }
        await viewModel.search("")
        let coffee = try #require(viewModel.sections.flatMap(\.expenses).first { $0.name == "Coffee" })

        await countingNotifications(from: viewModel, into: recorder) {
            await viewModel.delete(id: coffee.id)
        }

        #expect(names(viewModel) == ["Coffee", "Taxi"])
        #expect(viewModel.errorMessage != nil)
        #expect(recorder.notifications == 0)
    }

    @Test func deleteKeepsTheCurrentQuery() async throws {
        let viewModel = SearchViewModel(model: try makeContainer()) { _ in throw DeleteFailed() }
        await viewModel.search("Tax")
        #expect(names(viewModel) == ["Taxi"])

        let taxi = try #require(viewModel.sections.first?.expenses.first)
        await viewModel.delete(id: taxi.id)

        // The rollback re-runs the same query, not an empty one.
        #expect(names(viewModel) == ["Taxi"])
    }
}
