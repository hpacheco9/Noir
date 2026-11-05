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

        // The check runs in the background after a save: wait for it.
        private func save(_ amount: Decimal, id: PersistentIdentifier? = nil, to fixture: Fixture) async throws {
            try await fixture.provider.save(ExpenseForm(amount: amount, name: "Row", date: .now), id: id)
            await fixture.provider.budgetCheck?.value
        }

        private func rows(in container: ModelContainer) throws -> [Expense] {
            try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.amount)]))
        }

        @Test func savingCrossesEachLevelOnce() async throws {
            try await withFixture { fixture in
                try await save(50, to: fixture)
                #expect(fixture.alerts.isEmpty)

                try await save(35, to: fixture)
                #expect(fixture.alerts == ["1"])
                try await save(5, to: fixture)
                #expect(fixture.alerts == ["1"])

                try await save(20, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
                try await save(10, to: fixture)
                #expect(fixture.alerts == ["1", "2"])
            }
        }

        @Test func aFailedSaveAlertsNothing() async throws {
            try await withFixture { fixture in
                await #expect(throws: RepositoryError.invalidAmount) { try await save(0, to: fixture) }
                #expect(fixture.center.added.isEmpty)
            }
        }

        @Test func editingDownAndBackUpDoesNotAlertAgain() async throws {
            try await withFixture { fixture in
                try await save(90, to: fixture)
                #expect(fixture.alerts == ["1"])
                let id = try #require(try rows(in: fixture.container).first?.persistentModelID)

                try await save(50, id: id, to: fixture)
                try await save(95, id: id, to: fixture)
                #expect(fixture.alerts == ["1"])

                try await save(120, id: id, to: fixture)
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
                await fixture.provider.budgetCheck?.value

                #expect(fixture.alerts == ["1"])
                #expect(try rows(in: fixture.container).map(\.amount) == [90])
            }
        }

        @Test func expensesOutsideTheCurrentMonthDoNotCount() async throws {
            try await withFixture { fixture in
                let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
                try await fixture.provider.save(ExpenseForm(amount: 500, name: "Old", date: lastYear), id: nil)
                await fixture.provider.budgetCheck?.value
                #expect(fixture.alerts.isEmpty)
            }
        }
    }
}
