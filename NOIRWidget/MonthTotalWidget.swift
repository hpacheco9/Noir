//
//  MonthTotalWidget.swift
//  NOIR
//

import SwiftUI
import WidgetKit

struct MonthTotalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthTotalWidget", provider: MonthTotalProvider()) { entry in
            MonthTotalWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(L10n.displayName))
        .description(Text(L10n.description))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}
