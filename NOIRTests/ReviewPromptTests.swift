//
//  ReviewPromptTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

/// A class so each test gets a throwaway suite (never the app's real defaults) that is removed in `deinit`.
final class ReviewPromptTests {
    private let suiteName = "ReviewPromptTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let policy = ReviewPromptPolicy()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func days(_ n: Double) -> Date { now.addingTimeInterval(-n * 24 * 60 * 60) }

    private func decide(count: Int, version: String? = nil, last: Date? = nil, current: String = "1.1") -> Bool {
        policy.shouldRequest(
            createdCount: count,
            lastPromptedVersion: version,
            lastPromptDate: last,
            currentVersion: current,
            now: now
        )
    }

    // MARK: Policy

    @Test func policyDefaults() {
        #expect(policy.threshold == 3)
        #expect(policy.minimumInterval == 14 * 24 * 60 * 60)
    }

    @Test func twoCreatesIsNotEnough() {
        #expect(decide(count: 2) == false)
    }

    @Test func thirdCreateOnNewVersionAsks() {
        #expect(decide(count: 3) == true)
    }

    @Test func countExactlyAtThresholdAsks() {
        #expect(ReviewPromptPolicy(threshold: 5).shouldRequest(
            createdCount: 5, lastPromptedVersion: nil, lastPromptDate: nil, currentVersion: "1.0", now: now
        ) == true)
    }

    @Test func sameVersionAlreadyPromptedDoesNotAsk() {
        #expect(decide(count: 10, version: "1.1", last: days(100)) == false)
    }

    @Test func newVersionWithin14DaysDoesNotAsk() {
        #expect(decide(count: 10, version: "1.0", last: days(5)) == false)
    }

    @Test func newVersionAfter20DaysAsks() {
        #expect(decide(count: 10, version: "1.0", last: days(20)) == true)
    }

    // MARK: Store

    @Test func recordCreatedExpenseIncrementsAndPersists() {
        let store = ReviewPromptStore(defaults: defaults)
        #expect(store.createdCount == 0)
        store.recordCreatedExpense()
        store.recordCreatedExpense()
        #expect(store.createdCount == 2)
        #expect(ReviewPromptStore(defaults: defaults).createdCount == 2)
        #expect(defaults.integer(forKey: "review.created_expense_count") == 2)
    }

    @Test func storeAsksOnThirdCreateOnly() {
        let store = ReviewPromptStore(defaults: defaults)
        store.recordCreatedExpense()
        store.recordCreatedExpense()
        #expect(store.shouldRequestReview(currentVersion: "1.0", now: now) == false)
        store.recordCreatedExpense()
        #expect(store.shouldRequestReview(currentVersion: "1.0", now: now) == true)
    }

    @Test func markPromptedStopsAskingForThatVersion() {
        let store = ReviewPromptStore(defaults: defaults)
        (0..<3).forEach { _ in store.recordCreatedExpense() }
        store.markPrompted(version: "1.0", date: now)
        #expect(store.shouldRequestReview(currentVersion: "1.0", now: now) == false)
        #expect(ReviewPromptStore(defaults: defaults).lastPromptedVersion == "1.0")
        #expect(ReviewPromptStore(defaults: defaults).lastPromptDate == now)
    }

    @Test func markPromptedAlsoBlocksNewVersionWithinInterval() {
        let store = ReviewPromptStore(defaults: defaults)
        (0..<3).forEach { _ in store.recordCreatedExpense() }
        store.markPrompted(version: "1.0", date: days(5))
        #expect(store.shouldRequestReview(currentVersion: "1.1", now: now) == false)
        store.markPrompted(version: "1.0", date: days(20))
        #expect(store.shouldRequestReview(currentVersion: "1.1", now: now) == true)
    }

    // MARK: Developer tools (Debug builds, Settings › Developer)

    #if DEBUG
    @Test func simulateEligibleAsksEvenAfterAPreviousAsk() {
        let store = ReviewPromptStore(defaults: defaults)
        store.recordCreatedExpense()
        store.markPrompted(version: "1.1", date: days(1))
        #expect(store.shouldRequestReview(currentVersion: "1.1", now: now) == false)

        store.simulateEligible(policy: policy)

        #expect(store.createdCount == policy.threshold)
        #expect(store.lastPromptedVersion == nil)
        #expect(store.lastPromptDate == nil)
        #expect(store.shouldRequestReview(currentVersion: "1.1", now: now) == true)
    }

    @Test func resetForgetsEverything() {
        let store = ReviewPromptStore(defaults: defaults)
        for _ in 0..<3 { store.recordCreatedExpense() }
        store.markPrompted(version: "1.1", date: days(1))

        store.reset()

        #expect(store.createdCount == 0)
        #expect(store.lastPromptedVersion == nil)
        #expect(store.lastPromptDate == nil)
        #expect(store.shouldRequestReview(currentVersion: "1.1", now: now) == false)
    }
    #endif
}
