//
//  OnboardingGlowBackground.swift
//  NOIR
//

import SwiftUI

struct OnboardingGlowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var glowColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var baseGlowOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.20
    }

    private var glowFalloff: Double {
        colorScheme == .dark ? 0.24 : 0.40
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height)

            ZStack {
                Color(uiColor: .systemBackground)

                glow(
                    at: UnitPoint(x: 0.82, y: 0.08),
                    radius: radius * 0.34,
                    opacity: baseGlowOpacity
                )

                glow(
                    at: UnitPoint(x: 0.12, y: 0.22),
                    radius: radius * 0.28,
                    opacity: baseGlowOpacity * 0.45
                )

                glow(
                    at: UnitPoint(x: 0.68, y: 0.93),
                    radius: radius * 0.42,
                    opacity: baseGlowOpacity * 0.72
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func glow(at center: UnitPoint, radius: CGFloat, opacity: Double) -> some View {
        RadialGradient(
            colors: [
                glowColor.opacity(opacity),
                glowColor.opacity(opacity * glowFalloff),
                .clear
            ],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }
}
