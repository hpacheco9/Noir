//
//  WidgetSnapshotPublisher.swift
//  NOIR
//

import Foundation
import WidgetKit

enum WidgetSnapshotPublisher {
    private static let repository = ExpenseRepositoryProvider(container: NOIRApp.sharedModelContainer)

    static func publish(now: Date = .now) async {
        guard let defaults = MonthTotalSnapshot.sharedDefaults,
              let month = SpendingPeriod.month.dateInterval(now: now) else { return }
        do {
            let (total, days) = try await repository.perform {
                (try await $0.overviewChart(period: .month, now: now).total, try await $0.cumulativeDays(in: month))
            }
            let snapshot = MonthTotalSnapshot(
                month: month,
                total: total,
                budget: UserDefaults.standard.double(forKey: OnboardingStorage.monthlyBudgetKey),
                currencyCode: UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode,
                days: days
            )
            guard snapshot != MonthTotalSnapshot.load(from: defaults) else { return }
            snapshot.save(to: defaults)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to publish widget snapshot: \(error)")
        }
    }
}
