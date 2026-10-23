//
//  NOIRWidgetBundle.swift
//  NOIR
//

import SwiftUI
import WidgetKit

@main
struct NOIRWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonthTotalWidget()
        AddExpenseControl()
    }
}
