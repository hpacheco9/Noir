//
//  GetStartedView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 10/09/2026.
//

import SwiftUI

struct GetStartedView: View {
    @State private var isAppeared: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Onboarding.welcomeTitle)
                .font(.system(size: 38, weight: .bold))

            Text(L10n.Onboarding.welcomeSubtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 15)
                .animation(.easeOut(duration: 0.6).delay(0.15), value: isAppeared)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 15)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: isAppeared)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    GetStartedView()
}
