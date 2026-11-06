//
//  BudgetAlert.swift
//  NOIR
//

import Foundation

nonisolated enum BudgetAlert: Int, Sendable {
    case nearLimit = 1
    case over

    // One value, "<year>-<month>.<level>": the highest level sent, and for which month.
    static let storageKey = "budget.alert"

    // Only a level above the last one sent fires, so spending that falls back never re-arms a level.
    static func next(total: Decimal, budget: Double, lastSent: BudgetAlert?) -> BudgetAlert? {
        guard let progress = BudgetProgress(total: total, budget: budget) else { return nil }
        let reached: BudgetAlert? = progress.isOver ? .over : progress.fraction >= 0.8 ? .nearLimit : nil
        guard let reached, reached.rawValue > lastSent?.rawValue ?? 0 else { return nil }
        return reached
    }

    static func state(for alert: BudgetAlert, now: Date, calendar: Calendar) -> String {
        "\(month(of: now, calendar: calendar)).\(alert.rawValue)"
    }

    static func lastSent(state: String?, now: Date, calendar: Calendar) -> BudgetAlert? {
        guard let parts = state?.split(separator: "."), parts.count == 2,
              parts[0] == month(of: now, calendar: calendar) else { return nil }
        return Int(parts[1]).flatMap(BudgetAlert.init(rawValue:))
    }

    // A new budget starts over: it may already be below or above the levels reached before.
    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private static func month(of date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }
}
