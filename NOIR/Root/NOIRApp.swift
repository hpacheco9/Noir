//
//  NOIRApp.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI
import SwiftData

@main
struct NOIRApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView(mainViewModel: MainViewModel(model: Self.sharedModelContainer))
           } else {
               NavigationStack {
                   MainOnboarding(onComplete: {
                       hasCompletedOnboarding = true
                   })
               }
           }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
