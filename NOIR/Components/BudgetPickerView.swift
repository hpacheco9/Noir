//
//  BudgetPickerView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct BudgetPickerView: View {
    @Binding var budget: Double
    
    private static let minValue = 0
    private static let maxValue = 5000
    private static let step = 10
    private let tickSpacing: CGFloat = 12
    
    @State private var scrollID: Int?
    @State private var isInitialScrollPositionReady = false
    
    private let highlightColor = Color.blue

    private var ticks: [Int] {
        Array(stride(from: Self.minValue, through: Self.maxValue, by: Self.step))
    }

    init(budget: Binding<Double>) {
        _budget = budget
        _scrollID = State(initialValue: Self.nearestTick(to: budget.wrappedValue))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("$\(Int(budget))")
                .font(.system(size: 48, weight: .bold))
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: budget)
                .padding(.top, -70)
            
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(ticks, id: \.self) { tickValue in
                            TickComponent(
                                value: tickValue,
                                isSelected: tickValue == scrollID,
                                highlightColor: highlightColor
                            )
                            .frame(width: tickSpacing)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollID)
                .scrollTargetBehavior(.viewAligned)
                .safeAreaPadding(.horizontal, (geo.size.width / 2) - (tickSpacing / 2))
            }
            .frame(height: 70)
        }
        .onAppear {
            scrollID = Self.nearestTick(to: budget)
            Task { @MainActor in
                await Task.yield()
                isInitialScrollPositionReady = true
            }
        }
        .onChange(of: scrollID) { oldValue, newValue in
            guard isInitialScrollPositionReady,
                  let newValue,
                  newValue != Self.nearestTick(to: budget) else { return }

            if newValue != Self.nearestTick(to: budget) {
                budget = Double(newValue)
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        .onChange(of: budget) { oldValue, newValue in
            let intValue = Self.nearestTick(to: newValue)
            if scrollID != intValue {
                withAnimation(.snappy) {
                    scrollID = intValue
                }
            }
        }
    }

    private static func nearestTick(to value: Double) -> Int {
        let roundedValue = Int((value / Double(step)).rounded() * Double(step))
        return min(max(roundedValue, minValue), maxValue)
    }
}

// MARK: - Tick Component
struct TickComponent: View {
    let value: Int
    let isSelected: Bool
    let highlightColor: Color
    
    private var tickHeight: CGFloat {
        if value % 100 == 0 { return 36 }   // maior
        if value % 50 == 0 { return 24 }    // médio
        return 14                           // menor
    }
    
    private var tickColor: Color {
        if isSelected {
            return highlightColor
        }
        return value % 100 == 0 ? .primary : (value % 50 == 0 ? .gray : .secondary.opacity(0.4))
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(tickColor)
                .frame(width: isSelected ? 2 : 1, height: tickHeight)
                .animation(.easeOut(duration: 0.1), value: isSelected)
            
            if value % 100 == 0 {
                Text("\(value)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? highlightColor : .secondary)
                    .fixedSize()
                    .offset(y: 28)
                    .animation(.easeOut(duration: 0.1), value: isSelected)
            }
        }
    }
}

#Preview {
    @Previewable @State var budget = 1000.00
    BudgetPickerView(budget: $budget)
}
