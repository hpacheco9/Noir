//
//  ReviewPrompt.swift
//  NOIR
//

import Foundation

/// Pure rule for when NOIR may ask the system for an App Store review. The system still decides silently whether the
/// prompt is actually shown (at most 3 times in 365 days), so this only keeps NOIR from asking too early or too often.
nonisolated struct ReviewPromptPolicy: Equatable, Sendable {
    /// Expenses created (not edited) before the first ask.
    var threshold = 3
    /// Minimum time between two asks, whatever the version.
    var minimumInterval: TimeInterval = 14 * 24 * 60 * 60

    func shouldRequest(
        createdCount: Int,
        lastPromptedVersion: String?,
        lastPromptDate: Date?,
        currentVersion: String,
        now: Date
    ) -> Bool {
        guard createdCount >= threshold else { return false }
        guard lastPromptedVersion != currentVersion else { return false }
        if let lastPromptDate, now.timeIntervalSince(lastPromptDate) < minimumInterval {
            return false
        }
        return true
    }
}

/// Persists the review-prompt state in `UserDefaults`. Reads are never cached: the Add Expense App Intent can run in
/// another process and bump the count while the app is alive.
nonisolated struct ReviewPromptStore {
    static let createdCountKey = "review.created_expense_count"
    static let lastPromptedVersionKey = "review.last_prompted_version"
    static let lastPromptDateKey = "review.last_prompt_date"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var createdCount: Int { defaults.integer(forKey: Self.createdCountKey) }
    var lastPromptedVersion: String? { defaults.string(forKey: Self.lastPromptedVersionKey) }
    var lastPromptDate: Date? { defaults.object(forKey: Self.lastPromptDateKey) as? Date }

    /// Call once per successfully created expense, never for edits.
    func recordCreatedExpense() {
        defaults.set(createdCount + 1, forKey: Self.createdCountKey)
    }

    func shouldRequestReview(
        currentVersion: String,
        now: Date = .now,
        policy: ReviewPromptPolicy = ReviewPromptPolicy()
    ) -> Bool {
        policy.shouldRequest(
            createdCount: createdCount,
            lastPromptedVersion: lastPromptedVersion,
            lastPromptDate: lastPromptDate,
            currentVersion: currentVersion,
            now: now
        )
    }

    /// Record when the request is made: there's no way to know whether the system actually showed it.
    func markPrompted(version: String, date: Date = .now) {
        defaults.set(version, forKey: Self.lastPromptedVersionKey)
        defaults.set(date, forKey: Self.lastPromptDateKey)
    }
}

#if DEBUG
/// Developer tools (Settings › Developer) for checking the prompt without logging real expenses.
extension ReviewPromptStore {
    /// Back to a fresh install: no expenses counted, never asked.
    func reset() {
        for key in [Self.createdCountKey, Self.lastPromptedVersionKey, Self.lastPromptDateKey] {
            defaults.removeObject(forKey: key)
        }
    }
}
#endif
