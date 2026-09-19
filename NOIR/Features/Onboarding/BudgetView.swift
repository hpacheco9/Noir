//
//  BudgetView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct BudgetView: View {
    @Binding var budget: Double
    var body: some View {
        VStack(spacing: 120){
            VStack(alignment: .leading, spacing: 12){
                Text("Set your monthly budget.")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                
                Text("We'll help you to stay on track and spend intentionally.")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            
            BudgetPickerView(budget: $budget)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top)
    }
}

#Preview {
    BudgetView(budget: .constant(1000))
}
