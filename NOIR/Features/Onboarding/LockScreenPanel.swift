//
//  LockScreenPanel.swift
//  NOIR
//

import SwiftUI

struct LockScreenPanel<Content: View>: View {
    var cornerRadius: CGFloat = 40
    var clockText: String = "9:41"
    var fadeHeight: CGFloat = 90
    var showsDynamicIsland: Bool = true
 
    @ViewBuilder var content: () -> Content
 
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
 
    var body: some View {
        VStack(spacing: 28) {
            Text(clockText)
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(isDark ? 0.42 : 0.30))
                .accessibilityHidden(true)
 
            content()
                .padding(.horizontal, 15)
        }
        .padding(.top, 68)
        .padding(.bottom, fadeHeight)
        .frame(maxWidth: .infinity)
        .background { panel }
        .overlay(alignment: .top) {
            if showsDynamicIsland { dynamicIsland }
        }
        .padding(.horizontal, 22)
    }
 
    // The bottom tone should sit close to the page behind it, so the fade has no visible seam.
    private var panelColors: [Color] {
        isDark
            ? [Color(white: 0.16), Color(white: 0.11)]
            : [Color(white: 0.91), Color(white: 0.96)]
    }
 
    // Kept low-contrast so it reads as a hint of the device, not a feature.
    private var dynamicIsland: some View {
        Capsule()
            .fill(.background.opacity(0.3))
            .frame(width: 100, height: 32)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.05), lineWidth: 1)
            }
            .padding(.top, 14)
            .accessibilityHidden(true)
    }
 
    private var panel: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: panelColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isDark ? 0.06 : 0.08), lineWidth: 1)
            }
            // Solid at the top, dissolves into the page at the bottom.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}
