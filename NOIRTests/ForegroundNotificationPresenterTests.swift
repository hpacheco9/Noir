//
//  ForegroundNotificationPresenterTests.swift
//  NOIRTests
//

import Testing
import UserNotifications
@testable import NOIR

struct ForegroundNotificationPresenterTests {
    @Test(arguments: ["budget.alert.2026-10.1", "budget.alert.2026-1.2", "recurring.6B1D1F0A-0000-4000-8000-000000000000"])
    func budgetAlertsAndRecurringRemindersShowWhileTheAppIsOpen(identifier: String) {
        let options = ForegroundNotificationPresenter.options(forIdentifier: identifier)
        #expect(options.contains(.banner))
        #expect(options.contains(.sound))
    }

    @Test(arguments: ["expense-added-6B1D1F0A", "", "budget", "something.else"])
    func everythingElseStaysSilent(identifier: String) {
        #expect(ForegroundNotificationPresenter.options(forIdentifier: identifier).isEmpty)
    }
}
