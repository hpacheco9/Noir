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
            HStack {
                Text("Hi,")
                    .font(.system(size: 42, weight: .bold))
                
                TextField("Nome", text: $name)
                    .font(.system(size: 42, weight: .bold))
                    .tint(.primary)
            }
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 15)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAppeared)

            Text("Tell us your name so we can personalize your experience in Noir.")
                .font(.headline)
                .foregroundStyle(.gray)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 15)
                .animation(.easeOut(duration: 0.6).delay(0.35), value: isAppeared)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    UserNameView(name: .constant(""))
}
