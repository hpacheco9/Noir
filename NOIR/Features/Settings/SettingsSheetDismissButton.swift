//
//  SettingsSheetDismissButton.swift
//  NOIR
//

import SwiftUI

struct SettingsSheetDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .close, action: action)
    }
}
