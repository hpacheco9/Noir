//
//  MainViewModelLoaderTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // The real loader (no injected one) against an in-memory store, with memos in an isolated suite.
    // Real `now` and `Calendar.current`, like the app. Nested in the serialized `CategoryBreakdownRepositoryTests`,
    // which checks that the memo generation stays put.
    @Suite
    struct MainViewModelLoaderTests {
        private func loaded(_ viewModel: MainViewModel) -> OverviewSnapshot? {
            if case .loaded(let snapshot) = viewModel.state { snapshot } else { nil }
        }

        @Test func previousTotalReachesTheSnapshot() async throws {
            let calendar = Calendar.current
            let month = try #require(SpendingPeriod.month.dateInterval(calendar: calendar))
            let lastMonth = try #require(SpendingPeriod.month.previousInterval(calendar: calendar))

            let container = try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)
            context.insert(Expense(amount: 10, name: "this month", date: month.start.addingTimeInterval(3600), category: .food))
            context.insert(Expense(amount: 40, name: "last month", date: lastMonth.start.addingTimeInterval(3600), category: .food))
            try context.save()

            let suite = "NOIRTests.loader.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                let viewModel = MainViewModel(model: container)

                viewModel.adoptPeriod(.month)
                await viewModel.fetchData()
                let monthSnapshot = try #require(loaded(viewModel))
                #expect(monthSnapshot.period == .month)
                #expect(monthSnapshot.total == 10)
                #expect(monthSnapshot.previousTotal == 40)

                // All Time has no previous period.
                viewModel.adoptPeriod(.allTime)
                await viewModel.fetchData()
                let allTimeSnapshot = try #require(loaded(viewModel))
                #expect(allTimeSnapshot.period == .allTime)
                #expect(allTimeSnapshot.total == 50)
                #expect(allTimeSnapshot.previousTotal == nil)
            }
        }
    }
}
