//
//  DateInterval+HalfOpen.swift
//  NOIR
//

import Foundation

extension DateInterval {
    /// `start <= date < end`. (`DateInterval.contains` also accepts `end`, which belongs to the next period.)
    nonisolated func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
