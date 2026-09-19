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
        VStack {
            NoirWatermark()
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : -10)
                .animation(.easeOut(duration: 0.8), value: isAppeared)
            
            VStack(alignment: .leading, spacing: 16){
                Text("Welcome to Noir.")
                    .font(.system(size: 44, weight: .bold))
             
             Text("Track your spending. Take control of your money.")
                 .font(.system(size: 20, weight: .medium))
                 .foregroundStyle(.gray)
                 .opacity(isAppeared ? 1 : 0)
                 .offset(y: isAppeared ? 0 : 15)
                 .animation(.easeOut(duration: 0.6).delay(0.4), value: isAppeared)
            }
            .padding(.top, -70)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 15)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAppeared)
     
        
            Spacer()
        }
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    GetStartedView()
}
