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
        struct AddExpenseViewRoute: RouteRepresentable {
            let routeId: String = "add-expense"

            func routeView() -> any View {
                AddExpenseView()
            }
        }

        return AddExpenseViewRoute()
    }

    static func editExpense(_ expense: ExpenseDTO) -> any RouteRepresentable {
        struct EditExpenseViewRoute: RouteRepresentable {
            let routeId: String
            let expense: ExpenseDTO

            func routeView() -> any View {
                EditExpenseView(expense: expense)
            }
        }

        return EditExpenseViewRoute(routeId: "edit-expense-\(expense.id)", expense: expense)
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

    static func budget() -> any RouteRepresentable {
        struct BudgetEditorViewRoute: RouteRepresentable {
            let routeId: String = "settings-budget"

            func routeView() -> any View {
                BudgetEditorView()
            }
        }

        return BudgetEditorViewRoute()
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
