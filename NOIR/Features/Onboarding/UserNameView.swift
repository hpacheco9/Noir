//
//  UserNameView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct UserNameView: View {
    @Binding var name: String
    @State private var isAppeared: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NoirWatermark()
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : -10)
                .animation(.easeOut(duration: 0.8), value: isAppeared)

            HStack {
                Text("Hi,")
                    .font(.system(size: 50, weight: .bold))
                
                TextField("Nome", text: $name)
                    .font(.system(size: 50, weight: .bold))
                    .tint(.primary)
            }
            .padding(.top, -70)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 15)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAppeared)

            Text("Tell us your name so we can personalize your experience in Noir.")
                .font(.headline)
                .foregroundStyle(.gray)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 15)
                .animation(.easeOut(duration: 0.6).delay(0.35), value: isAppeared)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            isAppeared = true
        }
    }
}

struct NoirWatermark: View {
    var imageName: String = "noir"
    var height: CGFloat = 400
    
    @State private var isFloating: Bool = false

    var body: some View {
        Image(.onboardingAsset)
            .resizable()
            .scaledToFit()
            .offset(y: isFloating ? -5 : 5)
            .animation(
                .easeInOut(duration: 3.5).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

#Preview {
    UserNameView(name: .constant(""))
}
