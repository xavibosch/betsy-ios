# Betsy — Dev Mode & User Mode Architecture

## Overview

Betsy operates with two parallel modes that coexist in the same binary:
a **Dev Mode** for testing and iteration without real APIs, and a **User Mode**
for real accounts connected to Firebase. Both share the same UI, the same
components, and the same service layer — the only difference is the data source.

---

## User Mode (real account)

The normal user experience, gated behind Firebase Auth:

- Signs up / logs in via email+password (Firebase Auth)
- Their league memberships, balances, bets, and arena duels live in Firestore
- Profile avatar stored locally per UID (`profileAvatarStoreData`)
- Sports data will come from a real API (not yet connected — placeholder provider active)
- All `LeagueService` calls hit Firestore in real time

**Status:** Auth + leagues + bets + arena are fully wired to Firebase.
Sports API integration is pending — `RealSportsDataProvider` exists but is
awaiting API key setup.

---

## Dev Mode (tester profiles)

A `#if DEBUG`-only layer that lets any developer test the full app experience
without a real account or real sports data.

### How it works

`LeagueService` has a `currentDevProfile` property that switches the active
identity between 5 states:

| Profile | Description |
|---------|-------------|
| `.real` | Uses the actual Firebase-authenticated user |
| `.tester1` — `.tester4` | Pre-seeded local identities with fake UIDs |

When a tester profile is active:
- All Firestore reads/writes use the tester's fake UID
- Leagues, bets, and arena data are real Firestore documents but scoped to that UID
- The UI shows the tester's display name and avatar initial

### Activating Dev Mode

1. In the Profile screen, long-press the app version label to activate Dev Mode
2. A **DEV** pill appears at the bottom of Profile (subtle, monospaced, shows current profile)
3. Tapping it opens the **Developer Panel**

### Developer Panel (`DeveloperPanel.swift`)

Sheet accessible only in `#if DEBUG` builds, from the Profile tab:

- **Switch account** — lists all 4 testers + real account. One tap to switch.
  Testers are seeded on first use (creates Firestore docs with initial balance,
  league membership, etc.)
- **Active profile leagues** — shows which leagues the current tester belongs to
- **Danger zone:**
  - *Delete dev data* — wipes all 4 tester Firestore documents
  - *Reset initial experience* — sets `hasSeenOnboarding = false` without clearing data
  - *Reset Arena limit* — clears the daily challenge cooldown for testing Arena flows

### Sports data in Dev Mode

`SportsDataMode` controls whether the app uses fake or real match data:

```
SportsDataProvider
├── FakeSportsDataProvider   ← used in dev / when no API key
└── RealSportsDataProvider   ← used in production (API pending)
```

`FakeSportsDataProvider` generates a set of plausible fixtures with realistic
odds, team names, and states (upcoming / live / finished). Bet resolution,
point settlement, and ranking updates all work end-to-end on fake data.

---

## Current state (May 2025)

| Area | Status |
|------|--------|
| Firebase Auth | ✅ Connected |
| Firestore (leagues, bets, arena) | ✅ Connected |
| Dev Mode / tester profiles | ✅ Fully functional |
| Fake sports data provider | ✅ Functional |
| Real sports API | ⏳ Pending — provider shell ready |
| Push notifications (reminders) | ✅ Local notifications wired |
| Profile stats | ✅ Computed from local ticket history |
| Arena 1v1 | ✅ Full flow in dev mode |

---

## Why this architecture

Building the full UX loop — betting, ranking, arena challenges, profile stats —
without a real sports API would otherwise be impossible in early development.
The fake provider + tester profiles let us validate the entire product experience,
run demos, and iterate on UI/UX while the API integration is prepared separately.
When `RealSportsDataProvider` is connected, the rest of the app requires zero changes.
