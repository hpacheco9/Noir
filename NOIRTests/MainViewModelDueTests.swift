//
//  MainViewModelDueTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // The Due list on Home against an in-memory store. Nested in the serialized suite because Add moves the memo
    // generation it checks; memos and cards live in a throwaway suite, review counts and reminders in fakes.
    @Suite
    struct MainViewModelDueTests {
        private final class Heard {
            var expenses = 0
        }

        private struct Fixture {
            let container: ModelContainer
            let viewModel: MainViewModel
            let review: ReviewPromptStore
            let center: RecordingNotificationCenter
        }

        private let emptyLoader: MainViewModel.Loader = { period, _ in
            OverviewSnapshot(period: period, points: [], total: 0, latest: [], hasAnyExpenses: false)
        }

        private func withFixture(_ body: (Fixture) async throws -> Void) async throws {
            let suite = "NOIRTests.due.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            let container = try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self, RecurringExpense.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let review = ReviewPromptStore(defaults: UserDefaults(suiteName: suite)!)
            let center = RecordingNotificationCenter()
            let viewModel = MainViewModel(
                model: container, loader: emptyLoader, reviewPrompt: review,
                notifications: NotificationService(center: center, defaults: UserDefaults(suiteName: suite)!)
            )
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                try await SavedCards.$suiteName.withValue(suite) {
                    try await body(Fixture(container: container, viewModel: viewModel, review: review, center: center))
                }
            }
        }

        private var today: Date { Calendar.current.startOfDay(for: .now) }

        private func days(_ count: Int, from date: Date) -> Date {
            Calendar.current.date(byAdding: .day, value: count, to: date)!
        }

        @discardableResult
        private func insertTemplate(
            _ name: String = "Rent", frequency: RecurrenceFrequency = .monthly, next: Date, into container: ModelContainer
        ) throws -> UUID {
            let context = ModelContext(container)
            let template = RecurringExpense(
                name: name, amount: 20, categoryRawValue: "home", card: "Visa",
                frequency: frequency, startDate: next, nextDueDate: next
            )
            context.insert(template)
            try context.save()
            return template.id
        }

        private func expenseDates(in container: ModelContainer) throws -> [Date] {
            try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)])).map(\.date)
        }

        private func nextDue(of id: UUID, in container: ModelContainer) throws -> Date? {
            try ModelContext(container).fetch(FetchDescriptor<RecurringExpense>(predicate: #Predicate { $0.id == id })).first?.nextDueDate
        }

        private func listening(
            to viewModel: MainViewModel, into heard: Heard, _ body: () async throws -> Void
        ) async rethrows {
            let token = NotificationCenter.default.addObserver(
                forName: .expensesDidChange, object: viewModel, queue: nil
            ) { _ in MainActor.assumeIsolated { heard.expenses += 1 } }
            defer { NotificationCenter.default.removeObserver(token) }
            try await body()
        }

        // MARK: Which rows show

        @Test func onlyRecurringExpensesDueByTheEndOfTodayShow() async throws {
            try await withFixture { fixture in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
                    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
                }
                try insertTemplate("future", next: date(11, 1), into: fixture.container)
                try insertTemplate("tomorrow", next: date(10, 16), into: fixture.container)
                try insertTemplate("late today", next: date(10, 15, hour: 23, minute: 30), into: fixture.container)
                try insertTemplate("today", next: date(10, 15), into: fixture.container)
                try insertTemplate("overdue", next: date(10, 14), into: fixture.container)

                #expect(fixture.viewModel.dueRecurring.isEmpty)
                await fixture.viewModel.loadDue(now: date(10, 15, hour: 10), calendar: calendar)

                // Soonest first; a row due tomorrow at 00:00 is not due yet.
                #expect(fixture.viewModel.dueRecurring.map(\.name) == ["overdue", "today", "late today"])
            }
        }

        @Test func fetchDataLoadsTheDueRowsToo() async throws {
            try await withFixture { fixture in
                try insertTemplate("Rent", next: days(-1, from: today), into: fixture.container)
                await fixture.viewModel.fetchData()
                #expect(fixture.viewModel.dueRecurring.map(\.name) == ["Rent"])
            }
        }

        // MARK: Add

        @Test func addInsertsTheExpenseAdvancesCountsAndAnnounces() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(next: today, into: fixture.container)
                await fixture.viewModel.loadDue()
                #expect(fixture.viewModel.dueRecurring.count == 1)

                let heard = Heard()
                try await listening(to: fixture.viewModel, into: heard) {
                    #expect(heard.expenses == 0)
                    try await fixture.viewModel.addDue(id)
                }

                #expect(try expenseDates(in: fixture.container) == [today])
                // The next occurrence is a month away, so the row is gone and its reminder is scheduled.
                #expect(fixture.viewModel.dueRecurring.isEmpty)
                let next = try #require(try nextDue(of: id, in: fixture.container))
                #expect(next == Calendar.current.date(byAdding: .month, value: 1, to: today))
                #expect(fixture.review.createdCount == 1)
                #expect(heard.expenses == 1)
                #expect(fixture.center.added.map(\.identifier) == ["recurring.\(id.uuidString)"])
                #expect(fixture.viewModel.processingDue.isEmpty)
            }
        }

        @Test func addKeepsTheRowWhenTheNextOccurrenceIsAlsoDue() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(frequency: .weekly, next: days(-14, from: today), into: fixture.container)
                await fixture.viewModel.loadDue()

                try await fixture.viewModel.addDue(id)
                #expect(fixture.viewModel.dueRecurring.map(\.nextDueDate) == [days(-7, from: today)])
                try await fixture.viewModel.addDue(id)
                #expect(fixture.viewModel.dueRecurring.map(\.nextDueDate) == [today])
                try await fixture.viewModel.addDue(id)
                #expect(fixture.viewModel.dueRecurring.isEmpty)

                #expect(try expenseDates(in: fixture.container) == [days(-14, from: today), days(-7, from: today), today])
                #expect(fixture.review.createdCount == 3)
            }
        }

        // MARK: Skip

        @Test func skipAdvancesWithoutAnExpenseOrReviewCount() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(frequency: .weekly, next: days(-14, from: today), into: fixture.container)
                await fixture.viewModel.loadDue()

                let heard = Heard()
                try await listening(to: fixture.viewModel, into: heard) {
                    try await fixture.viewModel.skipDue(id)
                    #expect(fixture.viewModel.dueRecurring.map(\.nextDueDate) == [days(-7, from: today)])
                    try await fixture.viewModel.skipDue(id)
                    #expect(fixture.viewModel.dueRecurring.map(\.nextDueDate) == [today])
                    try await fixture.viewModel.skipDue(id)
                }

                #expect(fixture.viewModel.dueRecurring.isEmpty)
                #expect(try nextDue(of: id, in: fixture.container) == days(7, from: today))
                #expect(try expenseDates(in: fixture.container).isEmpty)
                #expect(fixture.review.createdCount == 0)
                #expect(heard.expenses == 0)
                // The reminder for a past date is dropped, so only the last skip (a week ahead) schedules one.
                #expect(fixture.center.added.last?.identifier == "recurring.\(id.uuidString)")
                #expect(fixture.center.removed.contains("recurring.\(id.uuidString)"))
            }
        }

        // MARK: Failure and double taps

        @Test func aStaleRowAddsNothingAndCountsNothing() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(next: today, into: fixture.container)
                await fixture.viewModel.loadDue()
                // Stop Repeating from Settings while Home still shows the row.
                let context = ModelContext(fixture.container)
                for row in try context.fetch(FetchDescriptor<RecurringExpense>()) { context.delete(row) }
                try context.save()

                await #expect(throws: RepositoryError.notFound) { try await fixture.viewModel.addDue(id) }
                await #expect(throws: RepositoryError.notFound) { try await fixture.viewModel.skipDue(id) }

                // The failed taps reloaded the list, so the row is gone.
                #expect(try expenseDates(in: fixture.container).isEmpty)
                #expect(fixture.review.createdCount == 0)
                #expect(fixture.viewModel.dueRecurring.isEmpty)
                #expect(fixture.viewModel.processingDue.isEmpty)
                #expect(fixture.center.added.isEmpty)
            }
        }

        @Test func aRowAdvancedElsewhereCannotBeAddedAgain() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(frequency: .weekly, next: today, into: fixture.container)
                await fixture.viewModel.loadDue()
                #expect(fixture.viewModel.dueRecurring.count == 1)
                // Skipped from another screen, so it is a week away now.
                try await ExpenseRepository(modelContainer: fixture.container).skipDueOccurrence(id: id)

                await #expect(throws: RepositoryError.notDue) { try await fixture.viewModel.addDue(id) }

                #expect(try expenseDates(in: fixture.container).isEmpty)
                #expect(fixture.review.createdCount == 0)
                #expect(fixture.viewModel.dueRecurring.isEmpty)
                #expect(try nextDue(of: id, in: fixture.container) == days(7, from: today))
            }
        }

        @Test func aSecondTapWhileAddIsRunningDoesNothing() async throws {
            try await withFixture { fixture in
                let id = try insertTemplate(frequency: .weekly, next: days(-14, from: today), into: fixture.container)
                await fixture.viewModel.loadDue()

                async let first: Void = fixture.viewModel.addDue(id)
                async let second: Void = fixture.viewModel.addDue(id)
                _ = try await (first, second)

                #expect(try expenseDates(in: fixture.container) == [days(-14, from: today)])
                #expect(try nextDue(of: id, in: fixture.container) == days(-7, from: today))
                #expect(fixture.review.createdCount == 1)

                // Once the first one is done, the next tap goes through.
                try await fixture.viewModel.addDue(id)
                #expect(try expenseDates(in: fixture.container).count == 2)
            }
        }
    }
}
