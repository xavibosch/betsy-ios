# Architecture Overview

## App shape

Betsy is an iOS app built with SwiftUI and structured into feature modules under `APP/Features`.

The app uses:
- SwiftUI for UI and navigation
- Firebase Authentication for account access
- Firestore for shared multiplayer state
- `AppStorage` for local lightweight persistence

## Main domains

### Authentication
- email/password sign up and sign in
- anonymous/dev-friendly flows during testing
- account deletion and sign-out behavior

### User profile
- display name
- email
- avatar selection
- reminder preferences
- current dev/tester identity

### Leagues
- league creation
- join by code
- configurable rules
- members and standings
- active league resolution

### Betting
- match list
- competition filters
- pick selection
- single and multi-pick tickets
- stake selection
- ticket confirmation
- ticket history and state transitions

### Arena
- challenge setup
- incoming challenge state
- accepted / pending / active / declined flow
- duel pick flow
- per-league arena storage

### Simulation
- fake sports data
- delayed resolution behavior
- developer tooling
- profile switching and testable game-state evolution

## Key files

- `APP/_xApp.swift`
  App entry point and Firebase configuration
- `APP/HomeView.swift`
  Root routing between splash, onboarding, instructions tour, and tab shell
- `APP/BetsyLeagueService.swift`
  Primary shared service for user, league, challenge, arena, and Firestore behavior
- `APP/BetsyAPI.swift`
  Sports data manager and repository-facing odds / live / score logic

## State model philosophy

The app keeps product-critical multiplayer state in Firestore and user-facing lightweight preferences locally.

Examples of Firestore-backed state:
- users
- leagues
- members
- arenas
- challenges
- league configuration

Examples of local persisted state:
- selected language
- selected league id
- onboarding visibility
- local ticket draft/history helpers
- avatar cache

## Data direction

The architecture is intentionally split so the product can work in a hybrid mode:
- simulated data for testing and early UX validation
- real sports integrations later through repository/API layers

That makes it possible to iterate on:
- UX
- game loops
- challenge states
- league logic

without being blocked by live sports providers from day one.

