//
//  OverviewMemo.swift
//  NOIR
//

import Foundation
import os

/// Persisted chart totals for one period, updated incrementally instead of re-reading the whole window.
///
/// Invariant: the memo counts exactly the rows with `createdAt <= watermark` AND `date` inside the window.
nonisolated struct OverviewMemo: Codable, Sendable, Equatable {
    var windowStart: Date
    var windowEnd: Date
    /// Rows created after this are not counted yet and arrive via the delta.
    var watermark: Date
    var total: Decimal
    /// Per-bucket sums, indexed like `BucketLayout.starts`.
    var buckets: [Decimal]
    /// How many rows (in the window) the memo counts. Checked against the store to catch rows the watermark skipped.
    var count: Int
    /// The `now` the memo was computed for; rebuilds the same `BucketLayout`.
    var computedAt: Date
}

/// UserDefaults-backed memo storage (`overview.memo.v1.<period>`), safe to use from several repository instances.
///
/// Writes are two-phase so a load can never save a memo computed around a write it did not see:
/// `beginWrite()` before the store is changed, then `finishWrite(...)` (or `cancelWrite()`) once it is known.
/// A load saves its memo only if no write started or finished since it began (same generation) and none is in flight.
nonisolated enum OverviewMemoStore {
    private struct State {
        var generation = 0
        var inFlight = 0
    }
    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// Versioned: the unversioned keys of earlier builds are ignored and deleted.
    static func key(_ period: SpendingPeriod) -> String { "overview.memo.v1.\(period)" }

    private static let legacyCleanup: Void = {
        for period in SpendingPeriod.allCases {
            UserDefaults.standard.removeObject(forKey: "overview.memo.\(period)")
        }
    }()

    static var generation: Int { state.withLock { $0.generation } }

    static func load(_ period: SpendingPeriod) -> OverviewMemo? {
        _ = legacyCleanup
        guard let data = UserDefaults.standard.data(forKey: key(period)) else { return nil }
        return try? JSONDecoder().decode(OverviewMemo.self, from: data)
    }

    /// Saves only if nothing started or finished a write since `generation` was read, and none is in flight.
    static func save(_ memo: OverviewMemo, for period: SpendingPeriod, ifGeneration generation: Int) {
        state.withLock { state in
            guard state.generation == generation, state.inFlight == 0,
                  let data = try? JSONEncoder().encode(memo) else { return }
            UserDefaults.standard.set(data, forKey: key(period))
        }
    }

    static func remove(_ period: SpendingPeriod) {
        state.withLock { state in
            state.generation += 1
            UserDefaults.standard.removeObject(forKey: key(period))
        }
    }

    // MARK: Two-phase writes

    static func beginWrite() {
        state.withLock { state in
            state.generation += 1
            state.inFlight += 1
        }
    }

    /// The write failed: nothing changed in the store.
    static func cancelWrite() {
        state.withLock { state in
            state.inFlight = max(state.inFlight - 1, 0)
            state.generation += 1
        }
    }

    /// The write is committed. Applies an edit or delete to every memo in place (subtract `old`, add `new`), . Only rows already counted by a memo (`createdAt <= watermark`) are adjusted;
    /// newer ones arrive via the delta. Anything inconsistent drops that memo so the next load recomputes it.
    static func finishWrite(old: SpendingEntry? = nil, new: SpendingEntry? = nil, calendar: Calendar = .current) {
        state.withLock { state in
            state.inFlight = max(state.inFlight - 1, 0)
            state.generation += 1

            guard old != nil || new != nil else { return }

            for period in SpendingPeriod.allCases {
                guard var memo = decodeStored(period) else { continue }

                guard
                    let layout = SpendingBuckets.layout(for: period, calendar: calendar, now: memo.computedAt),
                    layout.window.start == memo.windowStart,
                    layout.window.end == memo.windowEnd,
                    layout.starts.count == memo.buckets.count
                else {
                    UserDefaults.standard.removeObject(forKey: key(period))
                    continue
                }

                var consistent = true
                for (entry, isAdd) in [(old, false), (new, true)] {
                    guard let entry, entry.createdAt <= memo.watermark,
                          let index = layout.index(for: entry.date) else { continue }
                    let amount = Decimal(entry.amount)
                    memo.buckets[index] += isAdd ? amount : -amount
                    memo.total += isAdd ? amount : -amount
                    memo.count += isAdd ? 1 : -1
                    if memo.buckets[index] < 0 || memo.total < 0 || memo.count < 0 { consistent = false }
                }

                if consistent, let data = try? JSONEncoder().encode(memo) {
                    UserDefaults.standard.set(data, forKey: key(period))
                } else {
                    UserDefaults.standard.removeObject(forKey: key(period))
                }
            }
        }
    }

    // MARK: Private (call with the lock held)

    private static func decodeStored(_ period: SpendingPeriod) -> OverviewMemo? {
        guard let data = UserDefaults.standard.data(forKey: key(period)) else { return nil }
        return try? JSONDecoder().decode(OverviewMemo.self, from: data)
    }
}
