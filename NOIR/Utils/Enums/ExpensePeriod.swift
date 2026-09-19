//
//  ExpensePeriod.swift
//  NOIR
//

import Foundation

enum ExpensePeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var id: Self { self }

    var dateInterval: DateInterval {
        let calendar = Calendar.current

        switch self {
        case .today:
            return calendar.dateInterval(of: .day, for: .now)!
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: .now)!
        case .month:
            return calendar.dateInterval(of: .month, for: .now)!
        }
    }
}
