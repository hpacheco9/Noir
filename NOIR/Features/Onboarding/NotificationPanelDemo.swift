//
//  NotificationPanelDemo.swift
//  NOIR
//
//  Created by Henrique Pacheco on 15/10/2026.
//

import SwiftUI

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
