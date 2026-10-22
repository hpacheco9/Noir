//
//  GlassNotificationCard.swift
//  NOIR
//

import SwiftUI

// MARK: - Glass background (Liquid Glass on iOS 26, material fallback before)

private struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Notification card

struct GlassNotificationCard<Icon: View>: View {
    let appName: String
    let timestamp: String
    let title: String
    let message: String
    @ViewBuilder var icon: () -> Icon

    private let cornerRadius: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                icon()
                    .frame(width: 38, height: 38)
                    .clipShape(.rect(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(timestamp)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 9)
                    }
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(GlassBackground(cornerRadius: cornerRadius))
        .contentShape(.rect(cornerRadius: cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.Onboarding.demoAccessibilityLabel(appName: appName, title: title, message: message)))
    }
}
