//
//  BudgetAlertRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // Writes through the provider with a fake notification centre. Nested in the serialized suite because
    // `repository.save` moves the memo generation it checks; memos, cards and the alert state live in a throwaway
    // UserDefaults suite, never `.standard`. Dates are "now": the provider checks the current month.
    @Suite
    struct BudgetAlertRepositoryTests {
        private struct Fixture {
            let container: ModelContainer
            let center: RecordingNotificationCenter
            let provider: ExpenseRepositoryProvider
            let defaults: UserDefaults

            var alerts: [String] {
                center.added.map(\.identifier).filter { $0.hasPrefix("budget.alert.") }.map { String($0.suffix(1)) }
            }
        }

        private func withFixture(budget: Double? = 100, _ body: (Fixture) async throws -> Void) async throws {
            let suite = "NOIRTests.budgetAlerts.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set("EUR", forKey: CurrencyPreference.storageKey)
            if let budget { defaults.set(budget, forKey: OnboardingStorage.monthlyBudgetKey) }
            defer { defaults.removePersistentDomain(forName: suite) }

            let container = try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self, RecurringExpense.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let center = RecordingNotificationCenter()
            let provider = ExpenseRepositoryProvider(
                container: container, notifications: NotificationService(center: center, defaults: defaults)
            )
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                try await SavedCards.$suiteName.withValue(suite) {
                    try await body(Fixture(container: container, center: center, provider: provider, defaults: defaults))
                }
            }
        }

        private func add(_ amount: Decimal, to fixture: Fixture) async throws {
            try await fixture.provider.save(ExpenseForm(amount: amount, name: "Row", date: .now), id: nil)
        }

        private func rows(in container: ModelContainer) throws -> [Expense] {
            try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.amount)]))
        }

        @Test func savingCrossesEachLevelOnce() async throws {
            try await withFixture { fixture in
                try await add(50, to: fixture)
                #expect(fixture.alerts.isEmpty)

                try await add(35, to: fixture)
                #expect(fixture.alerts == ["1"])
                try await add(5, to: fixture)
                #expect(fixture.alerts == ["1"])

                try await add(20, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
                try await add(10, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
            }
        }

        @Test func aSingleBigExpenseSendsOnlyTheOverAlert() async throws {
            try await withFixture { fixture in
                try await add(150, to: fixture)
                #expect(fixture.alerts == ["2"])
            }
        }

        @Test func noBudgetNeverAlerts() async throws {
            try await withFixture(budget: nil) { fixture in
                try await add(5000, to: fixture)
                #expect(fixture.center.added.isEmpty)
            }
        }

        @Test func aFailedSaveAlertsNothing() async throws {
            try await withFixture { fixture in
                await #expect(throws: RepositoryError.invalidAmount) { try await add(0, to: fixture) }
                #expect(fixture.center.added.isEmpty)
            }
        }

        @Test func editingDownAndBackUpDoesNotAlertAgain() async throws {
            try await withFixture { fixture in
                try await add(90, to: fixture)
                #expect(fixture.alerts == ["1"])
                let id = try #require(try rows(in: fixture.container).first?.persistentModelID)

                try await fixture.provider.save(ExpenseForm(amount: 50, name: "Row", date: .now), id: id)
                try await fixture.provider.save(ExpenseForm(amount: 95, name: "Row", date: .now), id: id)
                #expect(fixture.alerts == ["1"])

                try await fixture.provider.save(ExpenseForm(amount: 120, name: "Row", date: .now), id: id)
                #expect(fixture.alerts == ["1", "2"])
            }
        }

        @Test func deleteRunsTheCheckButNeverReArms() async throws {
            try await withFixture { fixture in
                let context = ModelContext(fixture.container)
                context.insert(Expense(amount: 82, name: "Big", date: .now, category: .food))
                context.insert(Expense(amount: 8, name: "Small", date: .now, category: .food))
                try context.save()
                let small = try #require(try rows(in: fixture.container).first?.persistentModelID)
                #expect(fixture.alerts.isEmpty)

                try await fixture.provider.delete(id: small)
                #expect(fixture.alerts == ["1"])

                try await add(60, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
                let big = try #require(try rows(in: fixture.container).last?.persistentModelID)
                try await fixture.provider.delete(id: big)
                try await add(30, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
            }
        }

        @Test func addingADueRecurringItemChecksTheBudget() async throws {
            try await withFixture { fixture in
                let context = ModelContext(fixture.container)
                let template = RecurringExpense(
                    name: "Rent", amount: 90, categoryRawValue: "food",
                    frequency: .weekly, startDate: .now, nextDueDate: .now
                )
                context.insert(template)
                try context.save()

                try await fixture.provider.addDueOccurrence(id: template.id)

                #expect(fixture.alerts == ["1"])
                #expect(try rows(in: fixture.container).map(\.amount) == [90])
            }
        }

        @Test func expensesOutsideTheCurrentMonthDoNotCount() async throws {
            try await withFixture { fixture in
                let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
                try await fixture.provider.save(ExpenseForm(amount: 500, name: "Old", date: lastYear), id: nil)
                #expect(fixture.alerts.isEmpty)
            }
        }
    }
}
