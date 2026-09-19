//
//  ProfileView.swift
//  NOIR
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 56, height: 56)

                        Text("H")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Profile.name)
                            .font(.body.weight(.medium))

                        Text(L10n.Profile.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(Text(L10n.Profile.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}
