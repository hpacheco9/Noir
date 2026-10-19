//
//  Routes.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI

enum MainRoutes {
    static func settings() -> any RouteRepresentable {
        struct SettingsViewRoute: RouteRepresentable {
            let routeId: String = "settings"
            
            func routeView() -> any View {
                SettingsView()
            }
        }
        
        return SettingsViewRoute()
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

extension SettingsRoutes {
    static func categories() -> any RouteRepresentable {
        struct CategoriesViewRoute: RouteRepresentable {
            let routeId: String = "settings-categories"

            func routeView() -> any View {
                CategoriesView()
            }
        }

        return CategoriesViewRoute()
    }

    static func newCategory() -> any RouteRepresentable {
        struct NewCategoryViewRoute: RouteRepresentable {
            let routeId: String = "settings-new-category"

            func routeView() -> any View {
                CategoryFormView(category: nil)
            }
        }

        return NewCategoryViewRoute()
    }

    static func editCategory(_ category: CategoryInfo) -> any RouteRepresentable {
        struct EditCategoryViewRoute: RouteRepresentable {
            let routeId: String
            let category: CategoryInfo

            func routeView() -> any View {
                CategoryFormView(category: category)
            }
        }

        return EditCategoryViewRoute(routeId: "settings-edit-category-\(category.key)", category: category)
    }

    static func shortcuts() -> any RouteRepresentable {
        struct ShortcutsViewRoute: RouteRepresentable {
            let routeId: String = "settings-shortcuts"

            func routeView() -> any View {
                ShortcutsView()
            }
        }

        return ShortcutsViewRoute()
    }

    static func safari(url: URL) -> any RouteRepresentable {
        struct SafariViewRoute: RouteRepresentable {
            let routeId: String
            let url: URL

            @MainActor
            func routeView() -> any View {
                SafariRouteContent(url: url)
            }
        }

        return SafariViewRoute(routeId: "settings-safari-\(url.absoluteString)", url: url)
    }
}

private struct SafariRouteContent: View {
    let url: URL

    var body: some View {
        SafariBrowserView(url: url, onFinish: {})
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}
