//
//  HeroAnimation.swift
//  NOIR
//
//  Created by Henrique Pacheco on 28/09/2026.
//

import SwiftUI

private struct HeroAnimationModifier: ViewModifier {
    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .transition(.opacity)
    }
}

// MARK: - Accessible Modifier

extension View {
    func heroAnimation() -> some View {
        modifier(HeroAnimationModifier())
    }
}
