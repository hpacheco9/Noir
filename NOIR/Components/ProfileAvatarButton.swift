//
//  ProfileAvatarButton.swift
//  NOIR
//

import SwiftUI

/// The round avatar in the top bar of Home, Dashboard and Search; opens Settings.
struct ProfileAvatarButton: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Button {
            coordinator.present(MainRoutes.settings(), mode: .large)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.gray)

                Text(verbatim: "H")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.SettingsView.title))
        .accessibilityShowsLargeContentViewer()
    }
}

#Preview {
    CoordinatorView {
        Text(verbatim: "Avatar")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileAvatarButton() } }
    }
    .environmentObject(Coordinator())
}
