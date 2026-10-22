//
//  DonutSlice.swift
//  NOIR
//

import SwiftUI

/// One sector of the Dashboard donut: a category, or the synthetic "All others" slice that sums the small ones.
struct DonutSlice: Identifiable, Equatable {
    /// Key of the synthetic slice. Not a category key, and not "Other" (that is a built-in category).
    static let restKey = "dashboard.rest"
    /// Above this many categories the smallest are summed into one slice.
    static let maxCategories = 6
    /// How many categories stay on their own when summing.
    static let topCount = 5

    /// Not `.gray`: that is what a custom category with an unknown colour shows, and the two must not look alike.
    static let restColor = Color(.systemGray2)

    let key: String
    let title: String
    let icon: String
    let color: Color
    let amount: Decimal
    let count: Int
    /// Category keys this slice stands for (one, or all the collapsed ones for the rest slice).
    let memberKeys: [String]
    /// Titles of `memberKeys`, in the same order.
    let memberTitles: [String]

    var id: String { key }
    var isRest: Bool { key == Self.restKey }

    /// Largest first, as in `breakdown.categories`. Up to 6 categories are shown as they are; with more, the top 5
    /// stay and the others are summed into a last "rest" slice.
    static func make(from categories: [CategorySpending], restTitle: String) -> [DonutSlice] {
        func slice(_ spending: CategorySpending) -> DonutSlice {
            DonutSlice(
                key: spending.info.key, title: spending.info.title, icon: spending.info.icon,
                color: spending.info.color, amount: spending.amount, count: spending.count,
                memberKeys: [spending.info.key], memberTitles: [spending.info.title]
            )
        }
        guard categories.count > maxCategories else { return categories.map(slice) }

        let rest = categories.dropFirst(topCount)
        let restSlice = DonutSlice(
            key: restKey, title: restTitle, icon: AssetName.System.rest, color: restColor,
            amount: rest.reduce(0) { $0 + $1.amount }, count: rest.reduce(0) { $0 + $1.count },
            memberKeys: rest.map(\.info.key), memberTitles: rest.map(\.info.title)
        )
        return categories.prefix(topCount).map(slice) + [restSlice]
    }

    /// The slice an angle on the chart's 0...total scale falls in, walking the sectors in plotted order. A sector
    /// owns `[start, end)`; whatever is at or past the last sector's start (up to the total, with a little tolerance
    /// for floating point) belongs to the last one. Out of range or no slices: `nil`.
    static func key(atAngle value: Double, in slices: [DonutSlice]) -> String? {
        guard value >= 0, let last = slices.last else { return nil }
        let total = slices.reduce(0.0) { $0 + $1.amount.doubleValue }
        guard value <= total + max(1e-9, total * 1e-9) else { return nil }
        var start = 0.0
        for slice in slices.dropLast() {
            start += slice.amount.doubleValue
            if value < start { return slice.key }
        }
        return last.key
    }

    /// The slice that shows a category: its own, or the rest slice when the category was collapsed into it.
    static func key(forCategory categoryKey: String, in slices: [DonutSlice]) -> String? {
        slices.first { $0.memberKeys.contains(categoryKey) }?.key
    }
}
