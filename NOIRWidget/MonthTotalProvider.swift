//
//  MonthTotalProvider.swift
//  NOIR
//

import Foundation
import WidgetKit

nonisolated struct MonthTotalEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let progress: BudgetProgress?
    let currencyCode: String
    let days: [Double]
    let dayCount: Int

    init(date: Date, snapshot: MonthTotalSnapshot?, calendar: Calendar = .current) {
        self.date = date
        total = snapshot?.total(asOf: date) ?? 0
        progress = BudgetProgress(total: total, budget: snapshot?.budget ?? 0)
        currencyCode = snapshot?.currencyCode ?? CurrencyPreference.defaultCode
        days = snapshot?.visibleDays(asOf: date, calendar: calendar) ?? []
        dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }
}

nonisolated struct MonthTotalProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthTotalEntry {
        MonthTotalEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthTotalEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthTotalEntry>) -> Void) {
        let now = Date.now
        let snapshot = loadSnapshot()
        var entries = [MonthTotalEntry(date: now, snapshot: snapshot)]
        let ends = [snapshot?.month.end, Calendar.current.dateInterval(of: .month, for: now)?.end]
        if let monthEnd = ends.compactMap({ $0 }).first(where: { $0 > now }) {
            entries.append(MonthTotalEntry(date: monthEnd, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> MonthTotalEntry {
        MonthTotalEntry(date: date, snapshot: loadSnapshot())
    }

    private func loadSnapshot() -> MonthTotalSnapshot? {
        MonthTotalSnapshot.sharedDefaults.flatMap(MonthTotalSnapshot.load(from:))
    }
}
