//
//  DonutFocus.swift
//  NOIR
//

import Foundation

/// What the donut's centre shows while something is highlighted.
struct DonutFocus: Equatable {
    let title: String
    let amount: Decimal
    /// E.g. "in All others" for a category that is collapsed into the rest slice.
    let subtitle: String?
}
