//
//  Routes.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI
import AVFoundation


enum MainRoutes {
    static func search(viewModel: SearchViewModel) -> any RouteRepresentable {
        struct SearchViewRoute: RouteRepresentable {
            let routeId = "search"
            let viewModel: SearchViewModel

            func routeView() -> any View {
                SearchView(viewModel: viewModel)
            }
        }

        return SearchViewRoute(viewModel: viewModel)
    }
    
    static func settings() -> any RouteRepresentable {
        struct SettingsViewRoute: RouteRepresentable {
            let routeId: String = "settings"
            
            func routeView() -> any View {
                SettingsView()
            }
        }
        
        return SettingsViewRoute()
    }
    
    static func search(nameSpace: Namespace.ID) -> any RouteRepresentable {
            struct SearchViewRoute: RouteRepresentable {
                let routeId: String = "search"
                let nameSpace: Namespace.ID

                @ViewBuilder
                func routeView() -> any View {
                    SearchView(viewModel: SearchViewModel(model: NOIRApp.sharedModelContainer))
                        .navigationTransition(.zoom(sourceID: SearchTransitionID.button, in: nameSpace))
                }
            }
            
            return SearchViewRoute(nameSpace: nameSpace)
    }
    
    static func addExpense() -> any RouteRepresentable {
            struct addExpenseViewRoute: RouteRepresentable {
                let routeId: String = "add-expense"

                @ViewBuilder
                func routeView() -> any View {
                    AddExpenseView(expense: nil)
                }
            }
            
            return addExpenseViewRoute()
    }
    
    static func editExpense(expense: ExpenseDTO?) -> any RouteRepresentable {
            struct editExpenseViewRoute: RouteRepresentable {
                let routeId: String = "add-expense"
                let expense: ExpenseDTO?

                @ViewBuilder
                func routeView() -> any View {
                    AddExpenseView(expense: expense)
                }
            }
            
            return editExpenseViewRoute(expense: expense)
    }
}



enum SettingsRoutes {
    static func Profile() -> any RouteRepresentable {
        struct ProfileViewRoute: RouteRepresentable {
            let routeId: String = "profile"
            
            func routeView() -> any View {
                ProfileView()
            }
        }
        
        return ProfileViewRoute()
    }
}
