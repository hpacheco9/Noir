//
//  UnavailableView.swift
//  NOIR
//

import SwiftUI

struct UnavailableView: View {
    let title: String
    let systemImage: String
    let description: String

    init(
        _ title: LocalizedStringResource,
        systemImage: String,
        description: LocalizedStringResource
    ) {
        self.title = String(localized: title)
        self.systemImage = systemImage
        self.description = String(localized: description)
    }

    init(_ title: String, systemImage: String, description: String) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
        } description: {
            Text(description)
                .font(.headline)
                .fontWeight(.regular)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    UnavailableView(
        L10n.MainView.emptyTitle,
        systemImage: AssetName.System.transactions,
        description: L10n.MainView.emptyDescription
    )
}
