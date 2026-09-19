//
//  MainOnboarding.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct MainOnboarding: View {
    var onComplete: () -> Void
    @State private var viewModel = OnboardingViewModel()
    var body: some View {
        VStack {
            Spacer()
            Group {
                switch viewModel.step {
                case .welcome: GetStartedView()
                case .name: UserNameView(name: $viewModel.name)
                case .budget: BudgetView(budget: $viewModel.budget)
                }
            }
            Spacer()
        }
        .safeAreaInset(edge: .bottom){
            Button {
                if viewModel.isLastStep {
                    viewModel.persist()
                    onComplete()
                } else {
                    viewModel.advance()
                }
            } label: {
                Text(viewModel.isLastStep ? "Get started" : "Continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .tint(.primary)
            .padding(.horizontal, 26)
            .buttonStyle(.glassProminent)
            .padding(.vertical, 5)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.isFirstStep {
                    Button("Back", systemImage: "chevron.left") { viewModel.goBack() }
                }
            }
        }
        .animation(.snappy, value: viewModel.step)
    }
}

#Preview {
    CoordinatorView {
        MainOnboarding(onComplete: {})
    }
    .environmentObject(Coordinator())
}
