//
//  SpendingPeriodTests.swift
//  NOIRTests
//

import Testing
import SwiftUI
import Foundation
@testable import NOIR

struct SpendingPeriodTests {
    @Test(arguments: SpendingPeriod.allCases)
    func rawValueRoundTrips(period: SpendingPeriod) {
        #expect(SpendingPeriod(rawValue: period.rawValue) == period)
    }

    @Test(arguments: SpendingPeriod.allCases)
    func rawValueIsTheCaseName(period: SpendingPeriod) {
        #expect(period.rawValue == "\(period)")
    }

    @Test func caseNameCheckFiresWhenRawValueDrifts() {
        enum Drifted: String { case day = "d" }
        #expect(Drifted.day.rawValue != "\(Drifted.day)")
    }

    @Test func memoKeysAreUnchanged() {
        let keys = SpendingPeriod.allCases.map { OverviewMemoStore.key($0) }
        #expect(keys == [
            "overview.memo.v2.day",
            "overview.memo.v2.week",
            "overview.memo.v2.month",
            "overview.memo.v2.year",
            "overview.memo.v2.allTime",
        ])
    }

    @Test func unknownRawValueIsNotAPeriod() {
        #expect(SpendingPeriod(rawValue: "decade") == nil)
        #expect(SpendingPeriod(rawValue: "") == nil)
    }

    @Test func appStoragePersistsTheCaseNameAndFallsBackOnJunk() throws {
        let suiteName = "SpendingPeriodTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "home.period"
        func stored() -> SpendingPeriod {
            AppStorage(wrappedValue: SpendingPeriod.day, key, store: defaults).wrappedValue
        }

        #expect(stored() == .day)

        defaults.set("allTime", forKey: key)
        #expect(stored() == .allTime)

        let storage = AppStorage(wrappedValue: SpendingPeriod.day, key, store: defaults)
        storage.wrappedValue = .week
        #expect(defaults.string(forKey: key) == "week")

        defaults.set("decade", forKey: key)
        #expect(stored() == .day)
    }
}
