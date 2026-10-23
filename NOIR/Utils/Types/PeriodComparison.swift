//
//  PeriodComparison.swift
//  NOIR
//

import Foundation

nonisolated struct PeriodComparison: Sendable, Equatable {
    enum Trend: Sendable, Equatable {
        case higher, lower, same
    }

    enum Value: Sendable, Equatable {
        case percent(Int)
        case amount(Decimal)
    }

    static let displayCap = 999
    private static let storedLimit = 1_000_000

    let value: Value

    init(percent: Int) {
        value = .percent(percent)
    }

    init(amount: Decimal) {
        value = .amount(amount)
    }

    var percent: Int? {
        if case .percent(let percent) = value { percent } else { nil }
    }

    var trend: Trend {
        switch value {
        case .percent(let percent): percent > 0 ? .higher : (percent < 0 ? .lower : .same)
        case .amount: .higher
        }
    }

    var exceedsCap: Bool {
        guard let percent else { return false }
        return abs(percent) > Self.displayCap
    }

    var numericValue: Double {
        switch value {
        case .percent(let percent): Double(min(abs(percent), Self.displayCap))
        case .amount(let amount): amount.doubleValue
        }
    }

    func formatted(currencyCode: String, locale: Locale = .current) -> String {
        switch value {
        case .percent:
            let text = (numericValue / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
            return exceedsCap ? ">" + text : text
        case .amount(let amount):
            return CurrencyPreference.string(for: amount, code: currencyCode)
        }
    }

    static func make(current: Decimal, previous: Decimal?) -> PeriodComparison? {
        guard let previous, previous >= 0 else { return nil }
        if previous == 0 {
            return current > 0 ? PeriodComparison(amount: current) : PeriodComparison(percent: 0)
        }
        var change = (current - previous) / previous * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &change, 0, .plain)
        let limit = Decimal(storedLimit)
        let clamped = min(max(rounded, -limit), limit)
        return PeriodComparison(percent: NSDecimalNumber(decimal: clamped).intValue)
    }
}
