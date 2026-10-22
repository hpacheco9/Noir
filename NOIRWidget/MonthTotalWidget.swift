//
//  MonthTotalWidget.swift
//  NOIR
//

import Charts
import SwiftUI
import WidgetKit

enum L10n {
    static let displayName: LocalizedStringResource = "widget.month_total.display_name"
    static let description: LocalizedStringResource = "widget.month_total.description"
    static let title: LocalizedStringResource = "widget.month_total.title"

    static func left(_ amount: String) -> LocalizedStringResource {
        "widget.month_total.left \(amount)"
    }
}

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

struct MonthTotalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthTotalEntry

    private var totalText: String {
        CurrencyPreference.string(for: entry.total, code: entry.currencyCode)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: totalText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                MonthLineChart(days: entry.days, dayCount: entry.dayCount)
                    .frame(height: 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium, .systemLarge:
            wide
        default:
            small
        }
    }

    private var wide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(verbatim: totalText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            
            MonthLineChart(days: entry.days, dayCount: entry.dayCount)
            
            if let progress = entry.progress {
                HStack {
                    Text(L10n.left(CurrencyPreference.string(for: progress.left, code: entry.currencyCode)))
                    Spacer()
                    Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: totalText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            MonthLineChart(days: entry.days, dayCount: entry.dayCount)
            if let progress = entry.progress {
                Text(L10n.left(CurrencyPreference.string(for: progress.left, code: entry.currencyCode)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var circular: some View {
        if let progress = entry.progress {
            Gauge(value: progress.fraction) {
                EmptyView()
            } currentValueLabel: {
                Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.body, design: .rounded, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Text(verbatim: entry.total.formatted(
                    CurrencyPreference.formatStyle(for: entry.currencyCode).precision(.fractionLength(0))
                ))
                .font(.system(.body, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(4)
            }
        }
    }
}

/// Running total through the month: the x axis spans the whole month, so the line grows day by day.
private struct MonthLineChart: View {
    let days: [Double]
    let dayCount: Int

    var body: some View {
        Chart {
            ForEach(Array(days.enumerated()), id: \.offset) { day in
                AreaMark(x: .value("Day", day.offset + 1), y: .value("Total", day.element))
                    .foregroundStyle(Color.primary.opacity(0.12))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", day.offset + 1), y: .value("Total", day.element))
                    .foregroundStyle(Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = days.last {
                PointMark(x: .value("Day", days.count), y: .value("Total", last))
                    .foregroundStyle(Color.primary)
                    .symbolSize(40)
            }
        }
        .tint(.primary)
        .chartXScale(domain: 1...max(dayCount, 2))
        .chartYScale(domain: 0...max(days.last ?? 0, 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

@main
struct MonthTotalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthTotalWidget", provider: MonthTotalProvider()) { entry in
            MonthTotalWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(L10n.displayName))
        .description(Text(L10n.description))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}
