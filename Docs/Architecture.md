# Cusp Architecture

## Layer Overview

- `CuspApp/Services`: bridge layer for platform/runtime side effects (local proxy runtime, system proxy switching, launch-at-login, secure credential access).
- `CuspApp/ViewModels`: application state and orchestration.
- `CuspApp/Views` + `CuspApp/UI`: SwiftUI presentation and reusable view components.
- `Sources/CuspShared`: pure domain logic used by app/tests (parsing, config building, catalogs, rules, probes).
- `Tests/CuspSharedTests`: deterministic unit tests for shared domain logic.

## ViewModel Structure

`AppViewModel` is split by concern:

- Core state and runtime orchestration: [`CuspApp/ViewModels/AppViewModel.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/AppViewModel.swift)
- Localization helpers: [`CuspApp/ViewModels/Domains/AppViewModel+Localization.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Domains/AppViewModel+Localization.swift)
- Presentation-format helpers: [`CuspApp/ViewModels/Domains/AppViewModel+Presentation.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Domains/AppViewModel+Presentation.swift)
- Rules domain: [`CuspApp/ViewModels/Domains/AppViewModel+RulesDomain.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Domains/AppViewModel+RulesDomain.swift)
- Settings domain: [`CuspApp/ViewModels/Domains/AppViewModel+SettingsDomain.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Domains/AppViewModel+SettingsDomain.swift)
- Shared view-model types: [`CuspApp/ViewModels/Support/AppViewModel+Types.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Support/AppViewModel+Types.swift)
- Rule template catalog: [`CuspApp/ViewModels/Support/RuleTemplateCatalog.swift`](/Users/arvin/Documents/claude/Cusp/CuspApp/ViewModels/Support/RuleTemplateCatalog.swift)

## Design Principles

- Keep side effects in `Services`, not directly in `Views`.
- Keep protocol parsing/config generation in `CuspShared` so behavior stays testable.
- Keep UI text shaping out of domain models; expose display helpers from `ViewModel` extensions.
- Avoid large feature patches in `AppViewModel.swift`; prefer domain extension files when logic grows.

## Next Refactor Targets

- Extract subscription lifecycle actions from `AppViewModel.swift` into `Domains/AppViewModel+SubscriptionsDomain.swift`.
- Extract strategy-group actions into `Domains/AppViewModel+StrategyDomain.swift`.
- Move traffic/statistics formatting and sampling into a dedicated support component.
