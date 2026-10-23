//
//  ProfileAvatarButton.swift
//  NOIR
//

import SwiftUI

/// The round avatar in the top bar of Home, Dashboard and Search; opens Settings.
struct ProfileAvatarButton: View {
    @EnvironmentObject private var coordinator: Coordinator
    @AppStorage(ProfileStorage.nameKey) private var name = ""

    var body: some View {
        Button {
            coordinator.present(MainRoutes.settings(), mode: .large)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.gray)

                let initial = ProfileStorage.initial(of: name)
                if initial.isEmpty {
                    Image(systemName: AssetName.System.person)
                        .font(.body)
                        .foregroundColor(.white)
                } else {
                    Text(verbatim: initial)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundColor(.white)
                }
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
