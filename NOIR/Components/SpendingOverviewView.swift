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

    private var maxAmount: Double {
        let value = viewModel.dataPoints
            .map { NSDecimalNumber(decimal: abs($0.amount)).doubleValue }
            .max() ?? 0
        return Swift.max(value, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(
                    format: String(localized: L10n.SpendingOverview.totalSpent),
                    locale: .current,
                    selectedPeriod.title
                ))
                .font(.headline)
                .foregroundStyle(.secondary)

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
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
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

#Preview {
    //SpendingOverviewView(snapshot: ..., currencyCode: "", selectedPeriod: .constant(.week))
}
