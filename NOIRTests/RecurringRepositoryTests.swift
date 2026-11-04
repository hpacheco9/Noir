//
//  RecurringRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // Nested in the serialized suite because adding an occurrence moves the memo generation it checks.
    // Memos and remembered cards live in a throwaway UserDefaults suite, never `.standard`.
    @Suite
    struct RecurringRepositoryTests {
        private func calendar(_ zone: String = "UTC") -> Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            return calendar
        }

        private var utc: Calendar { calendar() }

        private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, in calendar: Calendar? = nil) -> Date {
            (calendar ?? utc).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }

        private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
            self.day(year, month, day, hour: 12)
        }

        private func ymd(_ date: Date, in calendar: Calendar) -> [Int] {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return [parts.year!, parts.month!, parts.day!]
        }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self, RecurringExpense.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func isolated(_ body: (UserDefaults) async throws -> Void) async throws {
            let suite = "NOIRTests.recurring.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set("EUR", forKey: CurrencyPreference.storageKey)
            defer { defaults.removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                try await SavedCards.$suiteName.withValue(suite) { try await body(defaults) }
            }
        }

        @discardableResult
        private func insertTemplate(
            _ name: String = "Rent",
            amount: Double = 12.5,
            category: String = "food",
            card: String = "",
            note: String = "",
            frequency: RecurrenceFrequency = .monthly,
            start: Date,
            next: Date? = nil,
            into container: ModelContainer
        ) throws -> UUID {
            let context = ModelContext(container)
            let template = RecurringExpense(
                name: name, amount: amount, categoryRawValue: category, card: card, note: note,
                frequency: frequency, startDate: start, nextDueDate: next ?? start
            )
            context.insert(template)
            try context.save()
            return template.id
        }

        private func expenses(in container: ModelContainer) throws -> [Expense] {
            try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))
        }

        private func templates(in container: ModelContainer) throws -> [RecurringExpense] {
            try ModelContext(container).fetch(FetchDescriptor<RecurringExpense>())
        }

        private func saveRecurring(
            _ repository: ExpenseRepository,
            id: UUID? = nil,
            name: String = "Rent",
            amount: Double = 12.5,
            category: String = "food",
            frequency: RecurrenceFrequency = .monthly,
            next: Date?,
            calendar: Calendar? = nil
        ) async throws -> RecurringExpenseDTO {
            try await repository.saveRecurring(
                id: id, amount: amount, name: name, categoryKey: category, card: "", note: "",
                frequency: frequency, nextDueDate: next, calendar: calendar ?? utc
            )
        }

        // MARK: Save / fetch / delete

        @Test func saveRecurringInsertsAndStoresTheDueDayAtNoon() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let saved = try await saveRecurring(repository, next: day(2026, 3, 10, hour: 15))

                #expect(saved.nextDueDate == noon(2026, 3, 10))
                #expect(try templates(in: container).first?.startDate == noon(2026, 3, 10))
                #expect(saved.frequency == .monthly)
                #expect(try await repository.fetchRecurring() == [saved])
            }
        }

        @Test func fetchRecurringIsSoonestDueFirst() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                try insertTemplate("later", start: noon(2026, 5, 1), into: container)
                try insertTemplate("sooner", start: noon(2026, 3, 1), into: container)
                try insertTemplate("middle", start: noon(2026, 4, 1), into: container)

                let names = try await ExpenseRepository(modelContainer: container).fetchRecurring().map(\.name)
                #expect(names == ["sooner", "middle", "later"])
            }
        }

        @Test func invalidAmountIsRejected() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                for amount in [0.0, -5.0, Double.infinity, Double.nan] {
                    await #expect(throws: RepositoryError.invalidAmount) {
                        try await saveRecurring(repository, amount: amount, next: day(2026, 3, 10))
                    }
                }
                #expect(try templates(in: container).isEmpty)
            }
        }

        @Test func unknownOrDeletedCategoryKeysBecomeFood() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let missing = CategoryInfo.key(forCustomID: UUID())
                let saved = try await saveRecurring(repository, category: missing, next: day(2026, 3, 10))
                #expect(saved.categoryInfo.key == "food")
                #expect(try templates(in: container).first?.categoryRawValue == "food")

                let transport = try await saveRecurring(repository, category: "transport", next: day(2026, 3, 10))
                #expect(transport.categoryInfo.key == "transport")
            }
        }

        @Test func renamingKeepsTheAnchorSoTheMonthEndDoesNotDrift() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let created = try await saveRecurring(repository, next: day(2026, 1, 31))
                let skipped = try await repository.skipDueOccurrence(id: created.id, calendar: utc)
                #expect(skipped.nextDueDate == noon(2026, 2, 28))

                // Same frequency and same next day: only the name changes.
                let renamed = try await saveRecurring(repository, id: created.id, name: "Flat", next: day(2026, 2, 28))
                #expect(renamed.name == "Flat")
                #expect(try templates(in: container).first?.startDate == noon(2026, 1, 31))
                let next = try await repository.skipDueOccurrence(id: created.id, calendar: utc)
                #expect(next.nextDueDate == noon(2026, 3, 31))
            }
        }

        @Test func aNilNextDateKeepsTheStoredScheduleAndAnExplicitOneRestartsIt() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let created = try await saveRecurring(repository, next: day(2026, 1, 31))
                try await repository.skipDueOccurrence(id: created.id, calendar: utc)

                let kept = try await saveRecurring(repository, id: created.id, name: "Flat", next: nil)
                #expect(kept.nextDueDate == noon(2026, 2, 28))
                #expect(try templates(in: container).first?.startDate == noon(2026, 1, 31))

                let moved = try await saveRecurring(repository, id: created.id, next: day(2026, 3, 15))
                #expect(moved.nextDueDate == noon(2026, 3, 15))
                #expect(try templates(in: container).first?.startDate == noon(2026, 3, 15))
                let afterMoved = try await repository.skipDueOccurrence(id: created.id, calendar: utc)
                #expect(afterMoved.nextDueDate == noon(2026, 4, 15))
            }
        }

        @Test func changingTheFrequencyRestartsTheAnchorFromTheStoredDate() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let created = try await saveRecurring(repository, next: day(2026, 4, 15))

                let weekly = try await saveRecurring(repository, id: created.id, frequency: .weekly, next: nil)
                #expect(weekly.frequency == .weekly)
                #expect(weekly.nextDueDate == noon(2026, 4, 15))
                let skipped = try await repository.skipDueOccurrence(id: created.id, calendar: utc)
                #expect(skipped.nextDueDate == noon(2026, 4, 22))
            }
        }

        @Test func deleteRemovesTheTemplateAndKeepsPastExpenses() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let id = try insertTemplate(start: noon(2026, 1, 10), into: container)
                try await repository.addDueOccurrence(id: id, calendar: utc)

                try await repository.deleteRecurring(id: id)
                #expect(try templates(in: container).isEmpty)
                #expect(try expenses(in: container).count == 1)
            }
        }

        // MARK: Time zones

        @Test func theScheduleKeepsItsDaysWhenTheTimeZoneChanges() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let lisbon = calendar("Europe/Lisbon")
                let newYork = calendar("America/New_York")
                let now = day(2026, 9, 1, in: lisbon)

                let created = try await saveRecurring(
                    repository, next: day(2026, 1, 31, in: lisbon), calendar: lisbon
                )
                #expect(ymd(created.nextDueDate, in: lisbon) == [2026, 1, 31])

                // Month by month, alternating zones: no day lost or doubled, the 31st clamps and returns.
                let expected = [[2026, 2, 28], [2026, 3, 31], [2026, 4, 30], [2026, 5, 31]]
                for (index, days) in expected.enumerated() {
                    let zone = index.isMultiple(of: 2) ? newYork : lisbon
                    let skipped = try await repository.skipDueOccurrence(id: created.id, now: now, calendar: zone)
                    #expect(ymd(skipped.nextDueDate, in: lisbon) == days)
                    #expect(ymd(skipped.nextDueDate, in: newYork) == days)
                }
            }
        }

        // MARK: Stale ids

        @Test func aStaleIdThrowsNotFoundEverywhereAndLeavesNoWriteInFlight() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let gone = try insertTemplate(start: noon(2026, 1, 10), into: container)
                // The repository loads it first, then another context deletes it.
                try await repository.skipDueOccurrence(id: gone, calendar: utc)
                let other = ModelContext(container)
                for row in try other.fetch(FetchDescriptor<RecurringExpense>()) { other.delete(row) }
                try other.save()

                await #expect(throws: RepositoryError.notFound) { try await repository.addDueOccurrence(id: gone, calendar: utc) }
                await #expect(throws: RepositoryError.notFound) { try await repository.skipDueOccurrence(id: gone, calendar: utc) }
                await #expect(throws: RepositoryError.notFound) { try await repository.deleteRecurring(id: gone) }
                await #expect(throws: RepositoryError.notFound) {
                    try await saveRecurring(repository, id: gone, next: day(2026, 3, 10))
                }
                #expect(try expenses(in: container).isEmpty)
                #expect(try templates(in: container).isEmpty)

                // A write left in flight would stop this load from saving its memo.
                _ = try await repository.overviewChart(period: .month)
                #expect(OverviewMemoStore.load(.month) != nil)
            }
        }

        // MARK: Add / Skip

        @Test func occurrencesNotDueYetCanNeitherBeAddedNorSkipped() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let id = try insertTemplate(start: noon(2026, 3, 12), into: container)
                let generation = OverviewMemoStore.generation

                // Due on the 12th: still tomorrow on the 11th.
                let before = day(2026, 3, 11, hour: 8)
                await #expect(throws: RepositoryError.notDue) { try await repository.addDueOccurrence(id: id, now: before, calendar: utc) }
                await #expect(throws: RepositoryError.notDue) { try await repository.skipDueOccurrence(id: id, now: before, calendar: utc) }
                #expect(try expenses(in: container).isEmpty)
                #expect(try templates(in: container).first?.nextDueDate == noon(2026, 3, 12))
                #expect(OverviewMemoStore.generation == generation)

                // The same day, even before noon, it is due.
                let sameDay = day(2026, 3, 12, hour: 8)
                let skipped = try await repository.skipDueOccurrence(id: id, now: sameDay, calendar: utc)
                #expect(skipped.nextDueDate == noon(2026, 4, 12))
                let later = day(2026, 4, 12, hour: 8)
                try await repository.addDueOccurrence(id: id, now: later, calendar: utc)
                #expect(try expenses(in: container).map(\.date) == [noon(2026, 4, 12)])
            }
        }

        @Test func addInsertsTheExpenseFromTheTemplateAndAdvances() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let id = try insertTemplate(
                    "Gym", amount: 29.9, category: "health", card: "Visa", note: "monthly fee",
                    start: noon(2026, 1, 31), into: container
                )
                let before = Date.now

                let updated = try await repository.addDueOccurrence(id: id, calendar: utc)

                let rows = try expenses(in: container)
                let row = try #require(rows.first)
                #expect(rows.count == 1)
                #expect(row.name == "Gym")
                #expect(row.amount == 29.9)
                #expect(row.categoryRawValue == "health")
                #expect(row.card == "Visa")
                #expect(row.expenseDescription == "monthly fee")
                #expect(row.date == noon(2026, 1, 31))
                #expect(row.createdAt >= before)
                #expect(updated.nextDueDate == noon(2026, 2, 28))
                #expect(try templates(in: container).first?.nextDueDate == noon(2026, 2, 28))
                // The card is offered for the next expense.
                #expect(defaults.stringArray(forKey: SavedCards.storageKey) == ["Visa"])
            }
        }

        @Test func addFallsBackToFoodWhenTheCategoryIsGone() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let id = try insertTemplate(category: CategoryInfo.key(forCustomID: UUID()), start: noon(2026, 1, 10), into: container)

                try await repository.addDueOccurrence(id: id, calendar: utc)
                #expect(try expenses(in: container).first?.categoryRawValue == "food")
            }
        }

        @Test func skipOnlyAdvances() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let id = try insertTemplate(card: "Visa", start: noon(2026, 1, 31), into: container)

                let updated = try await repository.skipDueOccurrence(id: id, calendar: utc)

                #expect(updated.nextDueDate == noon(2026, 2, 28))
                #expect(try expenses(in: container).isEmpty)
                #expect(defaults.stringArray(forKey: SavedCards.storageKey) == nil)
            }
        }

        @Test func missedOccurrencesAreWorkedThroughOneByOne() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                // Weekly since Jan 5; the user has not looked since.
                let id = try insertTemplate(frequency: .weekly, start: noon(2026, 1, 5), into: container)

                let first = try await repository.addDueOccurrence(id: id, calendar: utc)
                #expect(first.nextDueDate == noon(2026, 1, 12))
                let second = try await repository.skipDueOccurrence(id: id, calendar: utc)
                #expect(second.nextDueDate == noon(2026, 1, 19))
                let third = try await repository.addDueOccurrence(id: id, calendar: utc)
                #expect(third.nextDueDate == noon(2026, 1, 26))

                // Only the added ones exist, on the days they were due.
                #expect(try expenses(in: container).map(\.date) == [noon(2026, 1, 5), noon(2026, 1, 19)])
            }
        }

        @Test func addCountsInTheOverviewMemo() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let month = try #require(SpendingPeriod.month.dateInterval())
                let id = try insertTemplate(amount: 40, start: month.start, into: container)

                let before = try await repository.overviewChart(period: .month)
                #expect(before.total == 0)
                let generation = OverviewMemoStore.generation

                try await repository.addDueOccurrence(id: id)

                #expect(OverviewMemoStore.generation > generation)
                let after = try await repository.overviewChart(period: .month)
                #expect(after.total == 40)
                // The write finished, so this load could save its memo.
                #expect(OverviewMemoStore.load(.month)?.total == 40)
                // A skip adds nothing.
                try await repository.skipDueOccurrence(id: id, now: month.end.addingTimeInterval(86_400 * 40))
                #expect(try await repository.overviewChart(period: .month).total == 40)
            }
        }

        // MARK: Categories

        @Test func deletingACustomCategoryMovesItsRecurringExpensesToFood() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let context = ModelContext(container)
                let custom = CustomCategory(name: "Pets", symbol: AssetName.CategorySymbols.all[0], colorRawValue: "teal")
                context.insert(custom)
                try context.save()
                let key = CategoryInfo.key(forCustomID: custom.id)
                try insertTemplate("pet food", category: key, start: noon(2026, 1, 10), into: container)
                try insertTemplate("bus pass", category: "transport", start: noon(2026, 1, 10), into: container)

                let repository = ExpenseRepository(modelContainer: container)
                try await repository.deleteCategory(id: custom.id)

                let byName = Dictionary(uniqueKeysWithValues: try templates(in: container).map { ($0.name, $0.categoryRawValue) })
                #expect(byName == ["pet food": "food", "bus pass": "transport"])
                let shown = try await repository.fetchRecurring().first { $0.name == "pet food" }
                #expect(shown?.categoryInfo.key == "food")
            }
        }

        // MARK: Add Expense with Repeat

        private func saveExpense(
            _ repository: ExpenseRepository,
            id: PersistentIdentifier? = nil,
            date: Date,
            now: Date = .now,
            repeating: RecurrenceFrequency?
        ) async throws -> RecurringExpenseDTO? {
            try await repository.save(
                id: id, amount: 9.99, name: "Netflix", date: date, categoryKey: "leisure",
                description: "family plan", card: "Amex", repeating: repeating, now: now, calendar: utc
            )
        }

        @Test func addingAnExpenseWithRepeatCreatesTheTemplate() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)

                let created = try await saveExpense(
                    repository, date: day(2026, 1, 31, hour: 15), now: day(2026, 1, 31, hour: 16), repeating: .monthly
                )

                #expect(try expenses(in: container).count == 1)
                let template = try #require(try templates(in: container).first)
                #expect(try templates(in: container).count == 1)
                #expect(template.name == "Netflix")
                #expect(template.amount == 9.99)
                #expect(template.categoryRawValue == "leisure")
                #expect(template.card == "Amex")
                #expect(template.note == "family plan")
                #expect(template.frequency == .monthly)
                #expect(template.startDate == noon(2026, 1, 31))
                #expect(template.nextDueDate == noon(2026, 2, 28))
                // The returned value is what the reminder is scheduled from.
                #expect(created?.id == template.id)
                #expect(created?.nextDueDate == noon(2026, 2, 28))
            }
        }

        @Test func aPastDatedExpenseWithRepeatStartsFromTodayWithoutABacklog() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)

                let created = try await saveExpense(
                    repository, date: day(2026, 1, 31), now: day(2026, 5, 10, hour: 9), repeating: .monthly
                )

                // Counted from the Jan 31 anchor, but the first one after May 10.
                #expect(created?.nextDueDate == noon(2026, 5, 31))
                #expect(try templates(in: container).first?.startDate == noon(2026, 1, 31))
            }
        }

        @Test func addingAnExpenseWithoutRepeatCreatesNoTemplate() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)

                let created = try await saveExpense(repository, date: day(2026, 1, 31), repeating: nil)

                #expect(created == nil)
                #expect(try expenses(in: container).count == 1)
                #expect(try templates(in: container).isEmpty)
            }
        }

        @Test func editingAnExpenseNeverCreatesATemplate() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                _ = try await saveExpense(repository, date: day(2026, 1, 31), repeating: nil)
                let id = try #require(try expenses(in: container).first?.persistentModelID)

                let edited = try await saveExpense(repository, id: id, date: day(2026, 2, 1), repeating: .weekly)

                #expect(edited == nil)
                #expect(try templates(in: container).isEmpty)
            }
        }

        @Test func repeatDoesNotCreateATemplateWhenTheExpenseIsInvalid() async throws {
            try await isolated { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.invalidAmount) {
                    try await repository.save(
                        id: nil, amount: 0, name: "Netflix", date: day(2026, 1, 31), categoryKey: "food",
                        description: "", card: "", repeating: .monthly, calendar: utc
                    )
                }
                #expect(try templates(in: container).isEmpty)
                #expect(try expenses(in: container).isEmpty)
            }
        }

        // MARK: Provider: reminders follow every change

        private func provider(
            _ container: ModelContainer, center: RecordingNotificationCenter, defaults: UserDefaults
        ) -> ExpenseRepositoryProvider {
            ExpenseRepositoryProvider(
                container: container, notifications: NotificationService(center: center, defaults: defaults)
            )
        }

        private func reminderIDs(_ center: RecordingNotificationCenter) -> [String] {
            center.added.map(\.identifier)
        }

        @Test func saveWithRepeatSchedulesTheReminderOfTheNewTemplate() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let center = RecordingNotificationCenter()
                let provider = provider(container, center: center, defaults: defaults)
                let form = ExpenseForm(amount: 9.99, name: "Netflix", date: .now, repeats: .monthly)

                try await provider.save(form, id: nil)

                let id = try #require(try templates(in: container).first?.id)
                #expect(reminderIDs(center) == ["recurring.\(id.uuidString)"])
            }
        }

        @Test func saveWithoutRepeatSchedulesNothing() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let center = RecordingNotificationCenter()
                let provider = provider(container, center: center, defaults: defaults)

                try await provider.save(ExpenseForm(amount: 9.99, name: "Netflix", date: .now), id: nil)

                #expect(try templates(in: container).isEmpty)
                #expect(center.added.isEmpty)
            }
        }

        @Test func everyRecurringChangeReschedulesAndDeleteRemoves() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let center = RecordingNotificationCenter()
                let provider = provider(container, center: center, defaults: defaults)
                let soon = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
                let form = ExpenseForm(amount: 5, name: "Rent", date: soon)

                try await provider.saveRecurring(form, frequency: .monthly, nextDueDate: soon, id: nil)
                let id = try #require(try templates(in: container).first?.id)
                let key = "recurring.\(id.uuidString)"
                #expect(reminderIDs(center) == [key])

                try await provider.saveRecurring(form, frequency: .monthly, nextDueDate: nil, id: id)
                #expect(reminderIDs(center) == [key, key])

                // Weekly and due yesterday: the next one is six days away, so both reschedule.
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
                let addId = try insertTemplate(frequency: .weekly, start: yesterday, into: container)
                let skipId = try insertTemplate(frequency: .weekly, start: yesterday, into: container)
                try await provider.addDueOccurrence(id: addId)
                try await provider.skipDueOccurrence(id: skipId)
                #expect(reminderIDs(center).suffix(2) == ["recurring.\(addId.uuidString)", "recurring.\(skipId.uuidString)"])
                #expect(center.removed.isEmpty)

                try await provider.deleteRecurring(id: id)
                #expect(center.removed == [key])
                #expect(center.removedDelivered == [key])
            }
        }

        @Test func resyncSchedulesEveryFutureReminderAndDropsThePastOnes() async throws {
            try await isolated { defaults in
                let container = try makeContainer()
                let center = RecordingNotificationCenter()
                let provider = provider(container, center: center, defaults: defaults)
                let calendar = Calendar.current
                let nextWeek = calendar.date(byAdding: .day, value: 7, to: .now)!
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: .now)!
                let lastWeek = calendar.date(byAdding: .day, value: -7, to: .now)!
                let a = try insertTemplate("a", start: nextWeek, into: container)
                let b = try insertTemplate("b", start: nextMonth, into: container)
                let past = try insertTemplate("past", start: lastWeek, into: container)

                await provider.resyncReminders()

                #expect(Set(reminderIDs(center)) == ["recurring.\(a.uuidString)", "recurring.\(b.uuidString)"])
                #expect(center.removed == ["recurring.\(past.uuidString)"])
                #expect(center.removedDelivered == ["recurring.\(past.uuidString)"])
            }
        }
    }
}
