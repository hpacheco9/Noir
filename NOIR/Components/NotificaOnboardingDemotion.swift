//
//  Notification.swift
//  NOIR
//
//  Created by Henrique Pacheco on 15/10/2026.
//

import SwiftUI

// MARK: - Action model

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

struct NotificationPanelDemo: View {
   @State private var isVisible = false
   @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
   @Environment(\.accessibilityReduceMotion) private var reduceMotion

   var body: some View {
           LockScreenPanel {
               ZStack(alignment: .center) {
                   if isVisible {
                       GlassNotificationCard(
                           appName: "Noir",   // brand name, a literal like the rest of the app
                           timestamp: String(localized: L10n.Onboarding.demoTimestamp),
                           title: String(localized: L10n.Onboarding.demoTitle),
                           message: String(localized: L10n.Onboarding.demoMessage(
                               amount: CurrencyPreference.string(for: 186.20, code: currencyCode)
                           ))
                       ) {
                           ZStack {
                               Color.primary
                               Image("notas")
                                   .resizable()
                                   .scaledToFit()
                           }
                       }
                       .transition(.move(edge: .top).combined(with: .opacity))
                   }
               }
           }
           .hapticFeedback(.tap, trigger: isVisible)
           .task { await play() }

   }

   private func play() async {
       let entrance: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.7, bounce: 0.3)

       try? await Task.sleep(for: .seconds(0.8))
       withAnimation(entrance) { isVisible = true }
   }
}

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
        .accessibilityLabel("\(appName), \(title). \(message)")
    }
}


#Preview {
    ZStack {
        OnboardingGlowBackground()
        NotificationPanelDemo()
            .frame(maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    NotificationPanelDemo()
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.primary.opacity(0.1))
}
