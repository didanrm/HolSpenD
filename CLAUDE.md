# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

HolSpenD — Android expense app built on a **Daily Wallet**: the budget is split
into a daily allowance, unspent money carries into tomorrow, overspending shrinks
tomorrow. Spec lives in [PRD.MD](PRD.MD) (Indonesian); it is the source of truth
for business rules and is referenced by section number in code comments
(`PRD §10`, `PRD Rule 3`).

Flutter + Firebase. UI copy and user-facing strings are Indonesian; code,
comments and identifiers are English.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Single test file / single test:

```bash
flutter test test/wallet_calculator_test.dart
flutter test test/wallet_calculator_test.dart --plain-name "day 2 wallet"
```

`flutter test` needs no Firebase and no emulator — the wallet logic is pure Dart.

Firebase config is not committed. `lib/firebase_options.dart` ships as a
placeholder; `flutterfire configure` overwrites it and writes
`android/app/google-services.json`. Until then the app boots into
`SetupRequiredScreen` instead of crashing. Full setup steps in
[README.md](README.md) §3.

Deploy rules: `firebase deploy --only firestore:rules`.

## Architecture

### Wallet is derived, never stored

The one decision everything else follows from. [lib/logic/wallet_calculator.dart](lib/logic/wallet_calculator.dart)
recomputes the wallet from the full expense list on every read:

```
walletToday     = dailyAllowance * currentDay - spentBeforeToday
walletRemaining = walletToday - expenseToday
carryOver       = walletToday - dailyAllowance
```

Consequences to preserve when changing anything here:

- There is no midnight rollover job and there must not be one. A day that the
  app never saw still produces correct numbers.
- Editing or deleting an old expense retroactively corrects today's wallet.
- Duplicate allowance from a rollover running twice is structurally impossible.
- `walletToday`, `walletRemaining`, `carryOver`, `currentDay` **are** written to
  the budget doc (PRD §14, via `syncWalletMirror`) but are never read back by the
  app. They exist for notifications/analytics. Do not start reading them.

`WalletCalculator.compute` takes `now` as a parameter — never call `DateTime.now()`
inside it, that is what keeps every phase and edge case testable.

All date math goes through [lib/core/date_x.dart](lib/core/date_x.dart) on
calendar days with the time component stripped. Never diff raw timestamps: a
23:59 and a 00:01 purchase must land on different days regardless of hours.

`BudgetPhase` (upcoming / running / finished) gates the math. A finished budget
freezes its wallet at `endDate` rather than letting the day index run past the
period.

### Data flow

Riverpod, single direction, in [lib/providers/app_providers.dart](lib/providers/app_providers.dart):

```
authStateProvider -> activeBudgetProvider -> expensesProvider ─┐
                                          todayProvider ───────┴─> walletSnapshotProvider
```

`walletSnapshotProvider` is the only thing screens read for numbers. `todayProvider`
ticks at local midnight so an open app rolls over on its own.

### Firestore

```
users/{uid}                                    profile, activeBudgetId
users/{uid}/budgets/{budgetId}                 budget + wallet mirror
users/{uid}/budgets/{budgetId}/expenses/{id}   amount, category, note, date
```

`watchActiveBudget` is deliberately **unordered**: `createdAt` is a server
timestamp that reads back null until acknowledged, and Firestore drops
null-field docs from ordered queries — ordering would make a freshly created
budget flicker out of existence. Sorting happens client-side.

`createBudget` closes the previous budget, creates the new one and updates
`activeBudgetId` in one atomic batch, so there is never a moment with two active
budgets or zero (PRD Rule 4 & 5).

Current queries need no composite indexes. Adding a `where` + `orderBy` on
different fields would; check before introducing one.

### Navigation

No router package. `AuthGate` in [lib/main.dart](lib/main.dart) switches on
provider state: Splash → Login → (no active budget) CreateBudget → Dashboard.
Everything below is plain `Navigator.push`.

### Category keys

`ExpenseCategory.key` is what Firestore stores, never the label. Unknown keys
fall back to "Lainnya" so old data keeps rendering.

## Platform notes

- `android/gradlew` and `android/gradle/` are intentionally absent — the Flutter
  tool injects the wrapper on first run. Do not hand-write them.
- `minSdk 23` is required by firebase_auth 5.x; do not lower it.
- `google_sign_in` is pinned to `>=6.2.0 <7.0.0`. Version 7.x is a breaking API
  rewrite (`GoogleSignIn.instance.initialize()` / `authenticate()`);
  [lib/services/auth_service.dart](lib/services/auth_service.dart) targets the
  6.x API and must be rewritten to move up.
- `ThemeData.cardTheme` is deliberately unset — its type changed across Flutter
  versions (`CardTheme` → `CardThemeData`). Cards go through `SectionCard`.
- No `ios/` folder; PRD targets Android.

## Not built yet

20:00 notification (PRD §11, marked optional), Crashlytics (PRD §12 — Analytics
is wired, Crashlytics needs an extra Gradle plugin), everything in PRD §17
(roadmap v2).
