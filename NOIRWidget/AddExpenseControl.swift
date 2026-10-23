//
//  AddExpenseControl.swift
//  NOIR
//

import SwiftUI
import WidgetKit

struct AddExpenseControl: ControlWidget {
    static let kind = "henrique-dev.NOIR.AddExpenseControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAddExpenseIntent()) {
                Label {
                    Text(L10n.AddExpenseControl.displayName)
                } icon: {
                    Image(systemName: AssetName.System.add)
                }
            }
        }
        .displayName(L10n.AddExpenseControl.displayName)
        .description(L10n.AddExpenseControl.description)
    }
}
