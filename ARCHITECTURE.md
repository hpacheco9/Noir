# NOIR architecture

Living document for the iOS app. Update this file when structure, navigation, persistence, or design patterns change. Date the changelog entry; do not rewrite history — append.

**Last reviewed:** 2026-09-22

## What NOIR is

Native iOS expense tracker. SwiftUI + SwiftData. Local-only persistence. Feature folders, Coordinator-owned navigation, ViewModels talking to an actor repository via `ExpenseDTO`.

Repo layout:

- `NOIR/` — app sources
- `NOIR.xcodeproj/` — Xcode project (file-system synchronized group; new files under `NOIR/` are picked up automatically)

## Runtime flow

```
NOIRApp
  ├─ hasCompletedOnboarding == false → NavigationStack → MainOnboarding
  └─ true → RootView
                └─ CoordinatorView → ContentView
                       ViewModels → ExpenseRepository (@ModelActor) → SwiftData Expense
App Intents ──────────────────────────────────────────────────────────┘
                       (then NotificationCenter.expensesDidChange)
```

Gate: `@AppStorage("hasCompletedOnboarding")`. Shared store: `NOIRApp.sharedModelContainer` (schema: `Expense` only).

## Folder map

| Folder | Role | Main types |
|---|---|---|
| `Root` | App entry and shell | `NOIRApp`, `RootView` |
| `Router` | Coordinator navigation | `Coordinator`, `CoordinatorView`, `ModalCoordinatorView`, `RoutePresentationMode` |
| `Routes` | Type-erased destinations | `RouteRepresentable`, `Route`, `MainRoutes`, `SettingsRoutes` |
| `Features` | Screens by domain | Main, Expense, Search, Settings, Onboarding |
| `Repository` | Persistence | `ExpenseRepository`, `Expense` |
| `Components` | Shared UI | `ExpenseRow`, `SpendingOverviewView`, `UnavailableView`, camera, `BudgetPickerView` |
| `Services` | Side effects | `NotificationService` |
| `AppIntents` | Siri / Shortcuts | `AddExpenseIntent` |
| `Utils` | Cross-cutting | `L10n`, enums, `AssetName`, `SpendingDataPoint` |
| `Assets.xcassets` | Images and colors | App icon, onboarding art |

Shared UI lives in `Components/`. Feature-specific screens stay under `Features/<Name>/`.

## Features

### Main

Home list. `MainViewModel.State`: loading / empty / loaded.

`SpendingOverviewView` plus a list grouped by day. Both use `SpendingPeriod.contains`:

- **Today** — same calendar day
- **Week** — current calendar week
- **Month** — current calendar month
- **All time** — every expense

Empty list (no data at all, or none in the selected period) uses `UnavailableView`.

### Expense

Create / edit sheet, location picker. `ExpenseViewModel` is created in `RootView` and injected with `.environment`. Recurring expenses were removed; each `Expense` is a single event.

### Search

Push with zoom transition. `SearchViewModel` paginates (`fetchPage`, page size 50, 400ms debounce), groups by day.

### Settings

Currency (`AppStorage`), profile sheet, legal, Shortcuts. Noir Pro upgrade action is empty.

### Onboarding

Wizard: welcome → name → budget. Persists to `UserDefaults` (`profile.name`, `profile.monthlyBudget`, `profile.motivation`).

## Design patterns

| Pattern | How NOIR uses it | Where |
|---|---|---|
| Coordinator / Router | Views do not own `NavigationStack`; they call `navigate` / `present` / `dismiss` | `Router/`, `Routes/` |
| MVVM + Observation | `@Observable` ViewModels; views bind and call async methods | `Features/*/*ViewModel.swift` |
| Repository + `@ModelActor` | SwiftData off the main actor; UI receives `ExpenseDTO` | `Repository.swift` |
| DTO | `@Model Expense` stays in persistence; `ExpenseDTO` is `Sendable` for UI | `MainViewModel.swift` |
| Protocol + type erasure | `RouteRepresentable` boxed in `Route` for `NavigationPath` / sheets | `Route.swift` |
| State machine | `MainViewModel.State`, `OnboardingViewModel.Step` | Main, Onboarding |
| Factory methods | `MainRoutes` / `SettingsRoutes` build route objects | `Routes.swift` |
| Observer | `expensesDidChange` refreshes home after save / delete / intent | `Extensions.swift` |
| Adapter | `NotificationCenterClient` wraps `UNUserNotificationCenter` | `NotificationService.swift` |
| Singleton | `NOIRApp.sharedModelContainer`, `NotificationService.shared` | Root, Services |
| Strategy | `RoutePresentationMode` → detents vs `fullScreenCover` | `Coordinator.swift` |
| App Intent | Shortcuts write SwiftData, then post the same change event | `AddExpenseIntent.swift` |

Coordinator is still `ObservableObject` (Combine). ViewModels use Observation.

## Navigation

`Coordinator` holds `path`, `sheet`, `fullScreen`. Each modal gets a child `Coordinator`. Identity is `routeId`.

| Destination | Presentation |
|---|---|
| Search | push (`navigate`) |
| Add / edit expense | sheet `.large` |
| Settings | sheet `.large` |
| Profile | sheet `.medium` |

`addExpense` and `editExpense` currently share `routeId` `"add-expense"`. Hashable/Equatable treat them as the same destination.

## Data

**Model (`Expense`):** id, amount, name, date, category (stored as `categoryRawValue`), description, optional lat/long/`locationName`.

**Repository:** `fetch`, `fetchPage` (name search + offset/limit), `save`, `delete`. Maps to `ExpenseDTO`.

**Two write paths:** UI goes through `ExpenseRepository`. `AddExpenseIntent` uses `ModelContext` on the shared container. Both post `expensesDidChange`.

**Period filter:** `SpendingPeriod.contains(_:calendar:now:)` is the single rule for list and chart.

## Empty states

`UnavailableView` (`Components/UnavailableView.swift`) is the app-wide empty/unavailable standard (ContentView label + description typography). Use it instead of raw `ContentUnavailableView`. Call sites wrap list-row modifiers themselves when needed.

## Localization

Keys live in `Utils/Localization.swift` (`L10n`) and `Localizable.xcstrings` / `AppIntents.xcstrings`. Prefer `L10n` over string literals in views.

## Known leftovers / debt

Update this list when items are cleaned up or new debt is accepted.

- `Item.swift` — Xcode template model; not in the SwiftData schema
- `ExpensePeriod` — unused; overlaps `SpendingPeriod`
- Camera (`CameraView` / `CameraModel`) — not wired from features
- `RootView` has `.tabItem` without a `TabView`
- Noir Pro upgrade button has an empty action
- App Intents bypass the repository
- Duplicate search route factories in `MainRoutes` (one unused `search(viewModel:)`)
- Shared `routeId` for add vs edit expense

## How to update this file

When you change any of the following, edit the matching section and append a changelog line:

1. New folder, feature, or shared component → Folder map / Features / Components
2. Navigation or route IDs → Navigation
3. SwiftData model or repository API → Data
4. A pattern added or dropped → Design patterns
5. Debt fixed or introduced → Known leftovers

## Changelog

- **2026-09-22** — Initial architecture snapshot. Recurring expenses removed. Home list filtered by `SpendingPeriod`. `UnavailableView` introduced as the shared empty state.
