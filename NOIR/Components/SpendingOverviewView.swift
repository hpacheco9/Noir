//
//  SpendingChart.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import SwiftUI
import Charts

struct SpendingOverviewView: View {
    let expenses: [ExpenseDTO]
    let currencyCode: String

    @Binding var selectedPeriod: SpendingPeriod

    @State private var viewModel = SpendingOverviewViewModel()
    @State private var selectedLabel: String?

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

                Text(abs(viewModel.totalSpent), format: .currency(code: currencyCode))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                    .opacity(viewModel.isComputing ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isComputing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Chart(viewModel.dataPoints) { point in
                BarMark(
                    x: .value(String(localized: L10n.SpendingOverview.chartPeriod), point.label),
                    y: .value(String(localized: L10n.SpendingOverview.chartAmount), NSDecimalNumber(decimal: abs(point.amount)).doubleValue),
                    width: .fixed(28)
                )
                .cornerRadius(6)
                .annotation(position: .top) {
                    if selectedLabel == point.label {
                        Text(point.amount, format: .currency(code: currencyCode))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.background)
                            .clipShape(Capsule())
                    }
                }
            }
            .foregroundStyle(.primary)
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                guard newValue != nil else { return }

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            .frame(height: 240)
            .chartXAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(.snappy, value: selectedPeriod)
        .task(id: selectedPeriod) {
            viewModel.update(expenses: expenses, period: selectedPeriod)
        }
        .onChange(of: expenses) { _, newExpenses in
            viewModel.update(expenses: newExpenses, period: selectedPeriod)
        }
    }
}

#Preview {
    //SpendingOverviewView(totalSpent: 10, currencyCode: "", dataPoints: SpendingDataPoint.mockAllTime)
}
