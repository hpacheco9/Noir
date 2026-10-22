//
//  PeriodMenu.swift
//  NOIR
//

import SwiftUI

/// The toolbar filter button of Home and Dashboard; opens a menu to pick the period.
struct PeriodMenu: View {
    @Binding var selection: SpendingPeriod

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(SpendingPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            } label: {
                Text(L10n.Dashboard.periodPicker)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: AssetName.System.filter)
        }
        .accessibilityLabel(Text(L10n.Dashboard.periodPicker))
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Period")
            .toolbar { ToolbarItem(placement: .confirmationAction) { PeriodMenu(selection: .constant(.month)) } }
    }
}
