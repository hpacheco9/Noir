//
//  BudgetNotificationTests.swift
//  NOIRTests
//

import Testing
import Foundation
import UserNotifications
@testable import NOIR

final class BudgetNotificationTests {
    private let suiteName = "BudgetNotificationTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let center = RecordingNotificationCenter()
    private let service: NotificationService
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("EUR", forKey: CurrencyPreference.storageKey)
        defaults.set(500.0, forKey: OnboardingStorage.monthlyBudgetKey)
        service = NotificationService(center: center, defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func date(_ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func notify(_ spent: Decimal, month: Int = 10) async {
        await service.notifyBudgetIfNeeded(spent: spent, now: date(month), calendar: calendar)
    }

    private var ids: [String] { center.added.map(\.identifier) }

    @Test func noBudgetSendsNothing() async {
        defaults.removeObject(forKey: OnboardingStorage.monthlyBudgetKey)
        await notify(900)
        #expect(center.added.isEmpty)

        defaults.set(0.0, forKey: OnboardingStorage.monthlyBudgetKey)
        await notify(900)
        #expect(center.added.isEmpty)
    }

    @Test func eachLevelIsSentOncePerMonth() async {
        await notify(300)
        #expect(center.added.isEmpty)

        await notify(410)
        #expect(ids == ["budget.alert.2026-10.1"])
        await notify(450)
        await notify(499)
        #expect(ids.count == 1)

        await notify(520)
        #expect(ids == ["budget.alert.2026-10.1", "budget.alert.2026-10.2"])
        await notify(900)
        #expect(ids.count == 2)
    }

    @Test func spendingThatFallsBackAndRisesAgainDoesNotAlertAgain() async {
        await notify(520)
        #expect(ids == ["budget.alert.2026-10.2"])

        await notify(100)
        await notify(450)
        await notify(520)
        #expect(ids.count == 1)
    }

    @Test func aNewMonthRearmsBothLevels() async {
        await notify(410)
        await notify(520)
        #expect(ids.count == 2)

        await notify(410, month: 11)
        await notify(520, month: 11)
        #expect(ids.suffix(2) == ["budget.alert.2026-11.1", "budget.alert.2026-11.2"])

        await notify(520, month: 11)
        #expect(ids.count == 4)
    }

    @Test func withoutPermissionNothingIsSentOrClaimedUntilItIsGranted() async {
        center.status = .denied
        await notify(410)
        #expect(center.added.isEmpty)
        #expect(defaults.object(forKey: BudgetAlert.storageKey(for: date(10), calendar: calendar)) == nil)

        center.status = .notDetermined
        await notify(410)
        #expect(center.added.isEmpty)

        center.status = .authorized
        await notify(410)
        #expect(ids == ["budget.alert.2026-10.1"])
    }

    @Test func provisionalPermissionIsEnough() async {
        center.status = .provisional
        await notify(410)
        #expect(ids == ["budget.alert.2026-10.1"])
    }

    @Test func theMessageNamesTheAmountsInTheChosenCurrency() async throws {
        await notify(Decimal(string: "410.5")!)
        await notify(520)
        try #require(center.added.count == 2)

        let near = center.added[0].content
        let over = center.added[1].content
        #expect(near.title != over.title)
        #expect(near.body.contains(CurrencyPreference.string(for: Decimal(string: "410.5")!, code: "EUR")))
        #expect(near.body.contains(CurrencyPreference.wholeString(for: 500, code: "EUR")))
        #expect(over.body.contains(CurrencyPreference.string(for: Decimal(520), code: "EUR")))

        defaults.set("USD", forKey: CurrencyPreference.storageKey)
        await notify(520, month: 11)
        let usd = try #require(center.added.last).content
        #expect(usd.body.contains(CurrencyPreference.string(for: Decimal(520), code: "USD")))
        #expect(usd.body.contains(CurrencyPreference.wholeString(for: 500, code: "USD")))
    }
}
