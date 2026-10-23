//
//  PeriodComparison.swift
//  NOIR
//

import Foundation

nonisolated struct PeriodComparison: Sendable, Equatable {
    enum Trend: Sendable, Equatable {
        case higher, lower, same
    }

    static let displayCap = 999
    private static let storedLimit = 1_000_000

    let percent: Int

    var trend: Trend {
        if percent > 0 { .higher } else if percent < 0 { .lower } else { .same }
    }

    var magnitude: Int { min(abs(percent), Self.displayCap) }
    var exceedsCap: Bool { abs(percent) > Self.displayCap }

    func formattedPercent(locale: Locale = .current) -> String {
        let text = (Double(magnitude) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        return exceedsCap ? ">" + text : text
    }

    static func make(current: Decimal, previous: Decimal?) -> PeriodComparison? {
        guard let previous, previous > 0 else { return nil }
        var change = (current - previous) / previous * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &change, 0, .plain)
        let limit = Decimal(storedLimit)
        let clamped = min(max(rounded, -limit), limit)
        return PeriodComparison(percent: NSDecimalNumber(decimal: clamped).intValue)
    }
}
