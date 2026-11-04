//
//  BudgetAlert.swift
//  NOIR
//

import Foundation

nonisolated enum BudgetAlert: Int, Sendable {
    case nearLimit = 1
    case over

    init?(progress: BudgetProgress) {
        if progress.isOver {
            self = .over
        } else if progress.spent * 5 >= progress.budget * 4 {
            self = .nearLimit
        } else {
            return nil
        }
    }

    // Only a level above the last one sent fires, so spending that falls back never re-arms a level.
    static func next(total: Decimal, budget: Double, lastSent: BudgetAlert?) -> BudgetAlert? {
        guard let progress = BudgetProgress(total: total, budget: budget),
              let reached = BudgetAlert(progress: progress),
              reached.rawValue > lastSent?.rawValue ?? 0 else { return nil }
        return reached
    }

    static func storageKey(for now: Date, calendar: Calendar) -> String {
        let month = calendar.dateComponents([.year, .month], from: now)
        return "budget.alert.\(month.year ?? 0)-\(month.month ?? 0)"
    }
}
