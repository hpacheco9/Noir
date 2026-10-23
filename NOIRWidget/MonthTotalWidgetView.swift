//
//  MonthTotalWidgetView.swift
//  NOIR
//

import Charts
import SwiftUI
import WidgetKit

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var circular: some View {
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
