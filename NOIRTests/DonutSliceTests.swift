//
//  DonutSliceTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftUI
@testable import NOIR

struct DonutSliceTests {
    private func spending(_ key: String, _ amount: Decimal, count: Int = 1) -> CategorySpending {
        let builtIn = ExpenseCategory(rawValue: key) ?? .other
        return CategorySpending(info: CategoryInfo(builtIn: builtIn), amount: amount, count: count)
    }

    /// Seven built-in-backed categories, largest first (keys only need to be distinct for slicing).
    private func categories(_ n: Int) -> [CategorySpending] {
        let keys = ExpenseCategory.allCases.map(\.rawValue)
        return (0..<n).map { spending(keys[$0], Decimal(100 - $0 * 10), count: $0 + 1) }
    }

    @Test(arguments: [0, 1, 5, 6])
    func upToSixCategoriesAreShownAsTheyAre(count: Int) {
        let slices = DonutSlice.make(from: categories(count), restTitle: "All others")
        #expect(slices.count == count)
        #expect(!slices.contains { $0.isRest })
        #expect(slices.map(\.key) == categories(count).map(\.info.key))
    }

    @Test func sevenCategoriesGiveTopFivePlusRest() {
        let input = categories(7)
        let slices = DonutSlice.make(from: input, restTitle: "All others")
        #expect(slices.count == 6)
        #expect(slices.prefix(5).map(\.key) == input.prefix(5).map(\.info.key))

        let rest = slices[5]
        #expect(rest.isRest)
        #expect(rest.key == DonutSlice.restKey)
        #expect(rest.title == "All others")
        #expect(rest.amount == input[5].amount + input[6].amount)
        #expect(rest.count == input[5].count + input[6].count)
        #expect(rest.memberKeys == [input[5].info.key, input[6].info.key])
    }

    @Test func restSliceKeepsTheTotalIntact() {
        let input = categories(7)
        let slices = DonutSlice.make(from: input, restTitle: "x")
        #expect(slices.reduce(0) { $0 + $1.amount } == input.reduce(0) { $0 + $1.amount })
    }

    @Test func restKeyIsNotACategoryKey() {
        #expect(!ExpenseCategory.allCases.map(\.rawValue).contains(DonutSlice.restKey))
    }

    @Test func categoryMapsToItsOwnSliceOrTheRestSlice() {
        let input = categories(7)
        let slices = DonutSlice.make(from: input, restTitle: "x")
        #expect(DonutSlice.key(forCategory: input[0].info.key, in: slices) == input[0].info.key)
        #expect(DonutSlice.key(forCategory: input[6].info.key, in: slices) == DonutSlice.restKey)
        #expect(DonutSlice.key(forCategory: "missing", in: slices) == nil)
    }

    // MARK: Selection angle

    /// Amounts 50, 30, 20 (total 100).
    private var threeSlices: [DonutSlice] {
        DonutSlice.make(from: [spending("food", 50), spending("health", 30), spending("home", 20)], restTitle: "x")
    }

    @Test func angleMapsToTheSectorInPlottedOrder() {
        let slices = threeSlices
        #expect(DonutSlice.key(atAngle: 0, in: slices) == "food")
        #expect(DonutSlice.key(atAngle: 49.9, in: slices) == "food")
        #expect(DonutSlice.key(atAngle: 60, in: slices) == "health")
        #expect(DonutSlice.key(atAngle: 95, in: slices) == "home")
    }

    @Test func angleBoundariesBelongToTheNextSector() {
        let slices = threeSlices
        #expect(DonutSlice.key(atAngle: 50, in: slices) == "health")
        #expect(DonutSlice.key(atAngle: 80, in: slices) == "home")
    }

    @Test func endOfTheScaleBelongsToTheLastSector() {
        #expect(DonutSlice.key(atAngle: 100, in: threeSlices) == "home")
    }

    @Test func angleInTheCollapsedTailMapsToTheRestSlice() {
        let input = categories(7)
        let slices = DonutSlice.make(from: input, restTitle: "x")
        let topFive = input.prefix(5).reduce(0.0) { $0 + $1.amount.doubleValue }
        let total = input.reduce(0.0) { $0 + $1.amount.doubleValue }

        // Just before the tail starts: still the 5th sector. At its start and inside it: the rest slice.
        #expect(DonutSlice.key(atAngle: topFive - 0.001, in: slices) == input[4].info.key)
        #expect(DonutSlice.key(atAngle: topFive, in: slices) == DonutSlice.restKey)
        #expect(DonutSlice.key(atAngle: topFive + 10, in: slices) == DonutSlice.restKey)
        #expect(DonutSlice.key(atAngle: total - 0.001, in: slices) == DonutSlice.restKey)
    }

    @Test func endOfTheScaleClampsToTheLastSliceWithoutExactEquality() {
        let slices = DonutSlice.make(from: categories(7), restTitle: "x")
        let total = slices.reduce(0.0) { $0 + $1.amount.doubleValue }
        #expect(DonutSlice.key(atAngle: total, in: slices) == DonutSlice.restKey)
        // Floating point drift at the very end.
        #expect(DonutSlice.key(atAngle: total + 1e-12, in: slices) == DonutSlice.restKey)
        #expect(DonutSlice.key(atAngle: total + 1, in: slices) == nil)
    }

    @Test func restSliceNamesItsMembersAndIsNotPlainGray() {
        let slices = DonutSlice.make(from: categories(7), restTitle: "x")
        let rest = slices[5]
        #expect(rest.memberTitles.count == 2)
        #expect(rest.color != Color.gray)
    }

    @Test func outOfRangeAngleSelectsNothing() {
        let slices = threeSlices
        #expect(DonutSlice.key(atAngle: -0.1, in: slices) == nil)
        #expect(DonutSlice.key(atAngle: 100.1, in: slices) == nil)
        #expect(DonutSlice.key(atAngle: 10, in: []) == nil)
    }
}
