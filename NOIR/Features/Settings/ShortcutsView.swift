//
//  ShortcutsView.swift
//  NOIR
//

import SwiftUI

struct ShortcutsView: View {
    var body: some View {
        Form {
            Section {
                Text(L10n.ShortcutsView.description)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(L10n.Preferences.shortcuts))
        .navigationBarTitleDisplayMode(.inline)
    }
}
