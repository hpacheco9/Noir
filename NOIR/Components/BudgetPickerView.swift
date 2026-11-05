//
//  BudgetPickerView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct BudgetPickerView: View {
    @Binding var budget: Double
    
    private static let baseStep = 10
    private static let baseMax = 5000
    private let tickSpacing: CGFloat = 12
    
    @State private var scrollID: Int?
    @State private var hasUserScrolled = false
    
    private let highlightColor = Color.blue

    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    private var scale: Int { CurrencyPreference.budgetScale(for: currencyCode) }
    private var step: Int { Self.baseStep * scale }

    private var ticks: [Int] {
        Array(stride(from: 0, through: Self.baseMax * scale, by: step))
    }

    init(budget: Binding<Double>) {
        _budget = budget
        let code = UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
        let scale = CurrencyPreference.budgetScale(for: code)
        _scrollID = State(initialValue: Self.nearestTick(to: budget.wrappedValue, scale: scale))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(verbatim: CurrencyPreference.wholeString(for: budget, code: currencyCode))
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
                                step: step,
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
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { hasUserScrolled = true }
                }
                .safeAreaPadding(.horizontal, (geo.size.width / 2) - (tickSpacing / 2))
            }
            .frame(height: 70)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.Profile.budget))
        .accessibilityValue(Text(verbatim: CurrencyPreference.wholeString(for: budget, code: currencyCode)))
        .accessibilityAdjustableAction { direction in
            budget = Self.adjusted(budget, direction, scale: scale)
        }
        .onAppear {
            scrollID = Self.nearestTick(to: budget, scale: scale)
        }
        .onChange(of: scrollID) { oldValue, newValue in
            guard hasUserScrolled,
                  let newValue,
                  newValue != Self.nearestTick(to: budget, scale: scale) else { return }

            budget = Double(newValue)
            Haptics.play(.selection)
        }
        .onChange(of: budget) { oldValue, newValue in
            let intValue = Self.nearestTick(to: newValue, scale: scale)
            if scrollID != intValue {
                withAnimation(.snappy) {
                    scrollID = intValue
                }
            }
        }
    }

    private static func nearestTick(to value: Double, scale: Int) -> Int {
        let step = baseStep * scale
        let roundedValue = Int((value / Double(step)).rounded()) * step
        return min(max(roundedValue, 0), baseMax * scale)
    }

    // VoiceOver moves a hundred at a time (the ruler's major ticks), landing on that grid from wherever it is.
    static func adjusted(_ value: Double, _ direction: AccessibilityAdjustmentDirection, scale: Int) -> Double {
        let step = Double(100 * scale)
        let moved: Double
        switch direction {
        case .increment: moved = (value / step).rounded(.down) * step + step
        case .decrement: moved = (value / step).rounded(.up) * step - step
        @unknown default: return value
        }
        return min(max(moved, 0), Double(baseMax * scale))
    }
}

private struct TickComponent: View {
    let value: Int
    let step: Int
    let isSelected: Bool
    let highlightColor: Color
    
    private var isMajor: Bool { value % (step * 10) == 0 }
    private var isMedium: Bool { value % (step * 5) == 0 }
    
    private var tickHeight: CGFloat {
        if isMajor { return 36 }
        if isMedium { return 24 }
        return 14
    }
    
    private var tickColor: Color {
        if isSelected {
            return highlightColor
        }
        return isMajor ? .primary : (isMedium ? .gray : .secondary.opacity(0.4))
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(tickColor)
                .frame(width: isSelected ? 2 : 1, height: tickHeight)
                .animation(.easeOut(duration: 0.1), value: isSelected)
            
            if isMajor {
                Text(value, format: .number)
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
