//
//  CategoryDonutChart.swift
//  NOIR
//

import SwiftUI
import Charts

/// What the donut's centre shows while something is highlighted.
struct DonutFocus: Equatable {
    let title: String
    let amount: Decimal
    /// E.g. "in All others" for a category that is collapsed into the rest slice.
    let subtitle: String?
}

/// Donut of spending by category. The list under it acts as the legend, so the chart's own legend is hidden.
struct CategoryDonutChart: View {
    /// Sectors at least this share of the total get their icon drawn on them (colour alone must not carry the meaning).
    static let iconThreshold = 0.08
    /// Inner radius as a share of the outer one: a thin ring, so the hole has room for the period total.
    static let innerRadiusRatio: CGFloat = 0.78
    /// Rounded, separated segments: a corner radius about half the ring's thickness gives capsule ends, and the
    /// angular inset leaves a clear gap between neighbours.
    static let segmentCornerRadius: CGFloat = 12
    static let segmentGap: CGFloat = 5

    let slices: [DonutSlice]
    let total: Decimal
    let periodTitle: String
    let currencyCode: String
    /// The sector to emphasise; `nil` emphasises none.
    let selectedKey: String?
    /// What the centre shows for the highlighted sector or row; `nil` shows the period total.
    let focus: DonutFocus?
    /// The raw angle from `chartAngleSelection`, on the 0...total scale.
    @Binding var angleSelection: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value(L10n.Dashboard.amount, slice.amount.doubleValue),
                innerRadius: .ratio(Self.innerRadiusRatio),
                outerRadius: .inset(selectedKey == slice.key ? 0 : 4),
                angularInset: Self.segmentGap
            )
            .cornerRadius(Self.segmentCornerRadius)
            .foregroundStyle(by: .value(L10n.Dashboard.category, slice.key))
            .opacity(selectedKey == nil || selectedKey == slice.key ? 1 : 0.35)
            .annotation(position: .overlay) {
                if Self.share(of: slice.amount, in: total) >= Self.iconThreshold {
                    Image(systemName: slice.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(slice.title)
            .accessibilityValue(Self.valueDescription(for: slice, total: total, currencyCode: currencyCode))
        }
        .chartForegroundStyleScale(domain: slices.map(\.key), range: slices.map(\.color))
        .chartLegend(.hidden)
        .chartAngleSelection(value: $angleSelection)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let frame = geometry[plotFrame]
                    centerLabel(holeDiameter: min(frame.width, frame.height) * Self.innerRadiusRatio)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: slices)
        .animation(reduceMotion ? nil : .smooth, value: selectedKey)
        .accessibilityLabel(Text(L10n.Dashboard.chartLabel))
        // The centre label is hidden from VoiceOver, so the total is reachable here.
        .accessibilityValue(Text(L10n.Dashboard.announcement(
            period: periodTitle,
            total: CurrencyPreference.string(for: total, code: currencyCode)
        )))
    }

    // MARK: - Centre

    /// Tries the full label first and drops the lowest-priority lines until it fits the hole.
    @ViewBuilder
    private func centerLabel(holeDiameter: CGFloat) -> some View {
        let side = holeDiameter * 0.85

        Group {
            if let focus {
                let amountText = CurrencyPreference.string(for: focus.amount, code: currencyCode)
                let details = [Self.percentString(focus.amount, of: total), focus.subtitle].compactMap { $0 }

                ViewThatFits(in: .vertical) {
                    labelStack(title: focus.title, amount: amountText, details: details)
                    labelStack(title: focus.title, amount: amountText, details: [])
                    labelStack(title: nil, amount: amountText, details: [])
                }
            } else {
                let totalText = CurrencyPreference.string(for: total, code: currencyCode)

                ViewThatFits(in: .vertical) {
                    labelStack(title: periodTitle, amount: totalText, details: [])
                    labelStack(title: nil, amount: totalText, details: [])
                }
            }
        }
        .frame(width: side, height: side)
        .animation(reduceMotion ? nil : .smooth, value: focus)
        // The sectors and the list carry the information for VoiceOver.
        .accessibilityHidden(true)
    }

    private func labelStack(title: String?, amount: String, details: [String]) -> some View {
        VStack(spacing: 2) {
            if let title {
                Text(verbatim: title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text(verbatim: amount)
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())

            ForEach(details, id: \.self) { detail in
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: - Formatting

    static func share(of amount: Decimal, in total: Decimal) -> Double {
        total > 0 ? (amount / total).doubleValue : 0
    }

    static func percentString(_ amount: Decimal, of total: Decimal) -> String {
        share(of: amount, in: total).formatted(.percent.precision(.fractionLength(0)))
    }

    /// "€45,00, 23% of total"; for the rest slice it also names the categories it sums.
    static func valueDescription(for slice: DonutSlice, total: Decimal, currencyCode: String) -> String {
        let amount = CurrencyPreference.string(for: slice.amount, code: currencyCode)
        let percent = percentString(slice.amount, of: total)
        if slice.isRest {
            return String(localized: L10n.Dashboard.valueWithMembers(
                amount: amount, percent: percent, members: slice.memberTitles.formatted(.list(type: .and))
            ))
        }
        return String(localized: L10n.Dashboard.value(amount: amount, percent: percent))
    }
}

private func previewSlice(_ key: String, _ title: String, _ icon: String, _ color: Color, _ amount: Decimal) -> DonutSlice {
    DonutSlice(key: key, title: title, icon: icon, color: color, amount: amount, count: 1, memberKeys: [key], memberTitles: [title])
}

#Preview("Donut") {
    @Previewable @State var angle: Double?
    let slices = [
        previewSlice("food", "Food", AssetName.ExpenseCategory.food, .orange, 180),
        previewSlice("transport", "Transport", AssetName.ExpenseCategory.transport, .blue, 90),
        previewSlice("home", "Home", AssetName.ExpenseCategory.home, .indigo, 60),
        DonutSlice(key: DonutSlice.restKey, title: "All others", icon: AssetName.System.rest, color: DonutSlice.restColor,
                   amount: 30, count: 2, memberKeys: ["leisure", "health"], memberTitles: ["Leisure", "Health"]),
    ]
    CategoryDonutChart(
        slices: slices, total: 360, periodTitle: "This month", currencyCode: "EUR",
        selectedKey: nil, focus: nil, angleSelection: $angle
    )
    .frame(height: 260)
    .padding()
}
