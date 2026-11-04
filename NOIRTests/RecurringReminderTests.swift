//
//  RecurringReminderTests.swift
//  NOIRTests
//

import Testing
import Foundation
import UserNotifications
@testable import NOIR

final class RecordingNotificationCenter: NotificationCenterClient, @unchecked Sendable {
    var status: UNAuthorizationStatus
    private(set) var added: [UNNotificationRequest] = []
    private(set) var removed: [String] = []
    private(set) var removedDelivered: [String] = []

    init(status: UNAuthorizationStatus = .authorized) { self.status = status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func add(_ request: UNNotificationRequest) async throws { added.append(request) }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { removed += identifiers }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) { removedDelivered += identifiers }
}

struct RecurringReminderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func recurring(due: Date, name: String = "Rent", amount: Double = 12.5) -> RecurringExpenseDTO {
        let template = RecurringExpense(
            name: name, amount: amount, categoryRawValue: "food",
            frequency: .monthly, startDate: due, nextDueDate: due
        )
        return RecurringExpenseDTO(template, categories: [:])
    }

    private func schedule(
        _ item: RecurringExpenseDTO, now: Date, center: RecordingNotificationCenter
    ) async {
        let suite = "NOIRTests.reminder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("BRL", forKey: CurrencyPreference.storageKey)
        defer { defaults.removePersistentDomain(forName: suite) }
        await NotificationService(center: center, defaults: defaults)
            .scheduleRecurringReminder(item, now: now, calendar: calendar)
    }

    @Test func schedulesOneReminderAtNineOnTheDueDay() async throws {
        let center = RecordingNotificationCenter()
        let item = recurring(due: date(2026, 11, 20))
        await schedule(item, now: date(2026, 11, 4), center: center)

        let request = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(request.identifier == "recurring.\(item.id.uuidString)")
        #expect(request.content.title == String(localized: L10n.Notification.recurringDueTitle(name: "Rent")))
        #expect(request.content.body == CurrencyPreference.string(for: 12.5, code: "BRL"))
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 11)
        #expect(trigger.dateComponents.day == 20)
        #expect(trigger.dateComponents.hour == 9)
    }

    @Test func doesNotScheduleWithoutPermissionAndDropsThePendingOne() async {
        let item = recurring(due: date(2026, 11, 20))
        for status in [UNAuthorizationStatus.notDetermined, .denied] {
            let center = RecordingNotificationCenter(status: status)
            await schedule(item, now: date(2026, 11, 4), center: center)
            #expect(center.added.isEmpty)
            #expect(center.removed == ["recurring.\(item.id.uuidString)"])
        }
    }

    @Test func doesNotScheduleADateThatAlreadyPassed() async {
        let item = recurring(due: date(2026, 11, 3))
        let center = RecordingNotificationCenter()
        await schedule(item, now: date(2026, 11, 4), center: center)
        #expect(center.added.isEmpty)
        #expect(center.removed == ["recurring.\(item.id.uuidString)"])
    }

    @Test func dueTodaySchedulesOnlyBeforeNine() async {
        let item = recurring(due: date(2026, 11, 4))

        let early = RecordingNotificationCenter()
        await schedule(item, now: date(2026, 11, 4, hour: 8), center: early)
        #expect(early.added.count == 1)

        let late = RecordingNotificationCenter()
        await schedule(item, now: date(2026, 11, 4, hour: 9), center: late)
        #expect(late.added.isEmpty)
    }

    @Test func cancelRemovesThePendingAndTheDeliveredReminderById() {
        let center = RecordingNotificationCenter()
        let id = UUID()
        NotificationService(center: center).cancelRecurringReminder(id: id)
        #expect(center.removed == ["recurring.\(id.uuidString)"])
        #expect(center.removedDelivered == ["recurring.\(id.uuidString)"])
    }
}
