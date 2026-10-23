//
//  SpendingChart.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import SwiftUI
import Charts

struct SpendingOverviewView: View {
    let snapshot: OverviewSnapshot
    let currencyCode: String

    @Binding var selectedPeriod: SpendingPeriod

    @State private var viewModel = SpendingOverviewViewModel()
    @State private var selectedLabel: String?
    @State private var barsVisible = false
    @State private var chartID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxAmount: Double {
        let value = viewModel.dataPoints
            .map { NSDecimalNumber(decimal: abs($0.amount)).doubleValue }
            .max() ?? 0
        return Swift.max(value, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.SpendingOverview.totalSpent(for: selectedPeriod))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    if let comparison = viewModel.comparison,
                       let period = viewModel.appliedPeriod,
                       let label = L10n.SpendingOverview.comparison(comparison, for: period, currencyCode: currencyCode) {
                        ComparisonBadge(comparison: comparison, currencyCode: currencyCode, label: label)
                            .opacity(viewModel.isComputing ? 0.4 : 1)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
                    }
                }

                Text(verbatim: CurrencyPreference.string(for: abs(viewModel.totalSpent), code: currencyCode))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText(value: NSDecimalNumber(decimal: abs(viewModel.totalSpent)).doubleValue))
                    .opacity(viewModel.isComputing ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isComputing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Chart(viewModel.dataPoints) { point in
                let amount = NSDecimalNumber(decimal: abs(point.amount)).doubleValue

                BarMark(
                    x: .value(String(localized: L10n.SpendingOverview.chartPeriod), point.label),
                    y: .value(String(localized: L10n.SpendingOverview.chartAmount), barsVisible ? amount : 0),
                    // 30pt bars overlap past ~7 (Year's 12 months, busy days, many years): share the width instead.
                    width: viewModel.dataPoints.count > 7 ? .ratio(0.6) : .fixed(30)
                )
                .cornerRadius(6)
                .opacity(barsVisible ? 1 : 0)
                .annotation(position: .top) {
                    if selectedLabel == point.label {
                        Text(verbatim: CurrencyPreference.string(for: point.amount, code: currencyCode))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .id(chartID)
            .foregroundStyle(.primary)
            .chartYScale(domain: 0...maxAmount)
            .animation(barsVisible ? .spring(duration: 0.6, bounce: 0.15) : nil, value: barsVisible)
            .chartXSelection(value: $selectedLabel)
            .hapticFeedback(.selection, trigger: selectedLabel) { _, new in new != nil }
            .frame(height: 230)
            .chartXAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisValueLabel {
                        // Initials only on the axis: as x values they repeat (J, J) and would merge bars.
                        if let label = value.as(String.self) {
                            Text(verbatim: viewModel.appliedPeriod == .year ? String(label.prefix(1)).uppercased() : label)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        // Same separators as the amounts: the currency's locale, not the environment's.
                        if let amount = value.as(Double.self) {
                            Text(verbatim: amount.formatted(.number.locale(CurrencyPreference.locale(for: currencyCode))))
                        }
                    }
                }
            }

            BudgetSummaryView(monthTotal: snapshot.monthTotal, currencyCode: currencyCode)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task(id: selectedPeriod) {
            selectedLabel = nil

            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true

            withTransaction(instant) {
                barsVisible = false
            }

            viewModel.markLoading(for: selectedPeriod)
            
            if snapshot.period == selectedPeriod { viewModel.apply(snapshot) }
            await viewModel.waitUntilApplied(for: selectedPeriod)
            
            guard !Task.isCancelled else { return }

            withTransaction(instant) {
                chartID = UUID()
            }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                barsVisible = true
            }
        }
        .onChange(of: snapshot.id) {
            viewModel.apply(snapshot)
        }
    }
}

private struct ComparisonBadge: View {
    let comparison: PeriodComparison
    let currencyCode: String
    let label: LocalizedStringResource

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch comparison.trend {
        case .higher: .trendWorse
        case .lower: .trendBetter
        case .same: .trendSame
        }
    }

    private var symbol: String {
        switch comparison.trend {
        case .higher: AssetName.System.trendUp
        case .lower: AssetName.System.trendDown
        case .same: AssetName.System.trendFlat
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))

            Text(verbatim: comparison.formatted(currencyCode: currencyCode))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: comparison.numericValue))
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .foregroundStyle(color)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    //SpendingOverviewView(snapshot: ..., currencyCode: "", selectedPeriod: .constant(.week))
}
