//
//  PeriodComparison.swift
//  NOIR
//

import Foundation

/// How a period's spending compares with the whole period before it.
nonisolated struct PeriodComparison: Sendable, Equatable {
    enum Trend: Sendable, Equatable {
        case higher, lower, same
    }

    /// Signed whole percent, `(current - previous) / previous`.
    let percent: Int

    /// A change that rounds to 0% counts as the same.
    var trend: Trend {
        if percent > 0 { .higher } else if percent < 0 { .lower } else { .same }
    }

    func formattedPercent(locale: Locale = .current) -> String {
        (Double(abs(percent)) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// `nil` when there is nothing to compare with: no previous data or a previous total that is not positive.
    static func make(current: Decimal, previous: Decimal?) -> PeriodComparison? {
        guard let previous, previous > 0 else { return nil }
        var change = (current - previous) / previous * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &change, 0, .plain)
        return PeriodComparison(percent: NSDecimalNumber(decimal: rounded).intValue)
    }
}
