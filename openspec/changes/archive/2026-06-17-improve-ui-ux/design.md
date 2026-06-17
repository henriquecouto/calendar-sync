## Context

The app currently uses Material 3 (`useMaterial3: true`) with a static `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`. There is no `darkTheme`, no dynamic color from the system wallpaper, and no shared widget architecture. UI code is inline and uses hardcoded colors (`Colors.red`, `Colors.green`, etc.), bypassing the M3 color system. The `PermissionGate` creates its own `MaterialApp` with no theme at all.

The `HomePage` is a single `StatefulWidget` that serves as both the app's home screen and its configuration form. All controls (calendar dropdowns, event name field, interval selector, toggle, sync button) live in one scrollable `Column`. Sub-screens (`DryRunScreen`, `SyncStatusScreen`) are accessed via `IconButton` actions in the `AppBar`.

This design covers the technical approach to adopting Material You dynamic colors, restructuring the home into a Dashboard with a profile-list layout, extracting configuration into its own screen, and extracting reusable widgets — without touching sync logic, database, or background services.

## Goals / Non-Goals

**Goals:**
- Adopt system wallpaper-derived dynamic colors via the `dynamic_color` package
- Support light and dark themes, following the system brightness setting
- Replace the single config-form `HomePage` with a Dashboard that shows profile status, quick actions, and recent activity
- Extract the configuration form into a new `ProfileConfigScreen` (push from Dashboard)
- Use a list-based layout on the Dashboard to accommodate future multi-profile support, even though only one profile exists today
- Extract shared widgets (`ProfileCard`, `SyncPlanCard`, `EmptyState`, `SectionHeader`) from inline code
- Replace all hardcoded colors with `colorScheme` references
- Apply the Material You theme to the `PermissionGate` screen

**Non-Goals:**
- Adding bottom navigation, tabs, or a router package (GoRouter)
- Changing sync engine, mapping database, calendar service, or background task logic
- Implementing multi-profile support in the data layer (single profile in `SettingsService` remains)
- Adding animations or transitions (defer to future change)
- Modifying platform-specific Android code
- Adding pull-to-refresh on any screen (defer to future change)

## Decisions

### 1. Use `dynamic_color` package over manual implementation

**Choice:** Add the `dynamic_color` Flutter package.

**Rationale:** This is the official package from the Material Design team for extracting system wallpaper colors on Android 12+. It handles:
- Falling back to a seed color on platforms or OS versions that don't support dynamic colors
- Caching the extracted color scheme
- Reacting to system brightness changes

**Alternative considered:** Manual implementation using `ColorScheme.fromImageProvider` with the `PlatformDispatcher` singleton. Rejected because it adds significant complexity (platform checks, caching, wallpaper access) that `dynamic_color` already solves.

### 2. `DynamicColorBuilder` as root widget

**Choice:** Wrap the entire app (including `PermissionGate`) with `DynamicColorBuilder` at the entry point. The builder provides a `ColorScheme` that cascades to all descendants via `ThemeData`.

**Rationale:** `DynamicColorBuilder` is the recommended pattern from the `dynamic_color` package. It takes `onLight` and `onDark` callbacks that receive the dynamic `ColorScheme` and return a `ThemeData`. This keeps theme construction in one place and ensures all screens — including the permission gate — share the same palette.

### 3. Dashboard as home, config as sub-screen

**Choice:** Replace `HomePage` (config form) with a `DashboardScreen` that shows a list of sync profiles (currently one), quick actions, and recent activity. Tapping a profile card or "Configure" pushes `ProfileConfigScreen`. The `ProfileConfigScreen` contains the form that currently lives in `HomePage`.

**Rationale:** The configuration form is visited once during setup and rarely after. Forcing the user to scroll past it every time they open the app is poor UX. The Dashboard gives immediate value: "is my sync working?" is answered at a glance. Quick actions (Sync All, Dry Run) are prominent instead of hidden in the AppBar.

**Alternative considered:** Keep config as home with card-based layout. Rejected because it doesn't solve the fundamental problem — the home is a form the user has already filled out.

### 4. List-based layout on Dashboard (future-proof for multi-profile)

**Choice:** Render profile cards in a `ListView` or scrollable `Column`, even though only one profile exists today.

**Rationale:** A future change will allow multiple sync profiles. Using a list from day one means adding a second profile requires no layout changes — just another card appears. A single-card assumption would require refactoring the Dashboard later.

### 5. Configuration link inline in the profile card

**Choice:** Each profile card on the Dashboard shows a summary of the current configuration (source → target, event name, interval) and includes a tappable area or explicit "Configure" link that navigates to `ProfileConfigScreen`.

**Rationale:** Placing the link inside the card that displays the configuration creates spatial proximity — the user sees what's configured and can change it in the same visual unit. An alternative (gear icon in the AppBar) was rejected because it's disconnected from the content it relates to and would be a lone icon in an otherwise clean AppBar.

### 6. Screen navigation architecture

**Choice:** Keep simple `Navigator.push`/`pop` with `MaterialPageRoute`. No router package, no bottom navigation.

**Rationale:** The app has 4 screens (Dashboard, ProfileConfig, DryRun, SyncHistory) with a clear tree structure: Dashboard is root, everything else is push/pop. This doesn't warrant a router package. Bottom navigation was considered but rejected — with only 4 screens and a clear primary (Dashboard), tabs add complexity without value. The Dashboard surfaces everything the user needs.

**Screen hierarchy:**
```
Dashboard (root)
 ├── ProfileConfigScreen (push)
 ├── DryRunScreen (push)
 └── SyncHistoryScreen (push)
```

### 7. Shared widgets in `lib/widgets/`

**Choice:** Create `lib/widgets/` with four files:
- `profile_card.dart` — displays a single sync profile summary (source → target, event name, interval, status, inline actions)
- `sync_plan_card.dart` — displays a single sync plan entry (create/update/delete/skip/error) with icon, label, and semantic color
- `empty_state.dart` — reusable empty-state placeholder with icon, title, and optional subtitle
- `section_header.dart` — section label widget for grouping entries in dry-run and status screens

**Rationale:** These widgets are currently defined as private classes inside `dry_run_screen.dart` (`_CreateTile`, `_UpdateTile`, etc.) or not extracted at all. Extracting them eliminates duplication, makes them theme-aware (using `colorScheme`), and allows reuse across screens.

### 8. Replace hardcoded colors with semantic colorScheme roles

**Choice:** Map each hardcoded color to its semantic role:

| Current | Replaced by |
|---|---|
| `Colors.red` | `colorScheme.error` |
| `Colors.green` | `colorScheme.primary` |
| `Colors.orange` | `colorScheme.tertiary` |
| `Colors.grey` | `colorScheme.outline` or `colorScheme.surfaceVariant` |
| `Colors.deepPurple` | Removed entirely (dynamic color handles this) |

**Rationale:** Semantic color roles adapt to the dynamic color scheme and ensure proper contrast in both light and dark modes. Hardcoded colors would look out of place against the user's wallpaper-derived palette.

## Risks / Trade-offs

- **[Risk] `dynamic_color` returns a default seed on Android < 12 or non-Android platforms** → Mitigation: The package handles this internally — the app will still get a coherent color scheme derived from a fallback seed, just not the user's wallpaper.
- **[Risk] Hardcoded color replacement could miss some locations** → Mitigation: The implementation tasks include a grep for `Colors.` across `lib/` to find and evaluate every usage.
- **[Risk] Extracting config to a separate screen adds a navigation step for editing settings** → Trade-off: Accepted. Users configure once and benefit from the Dashboard every time they open the app. The extra tap during rare config edits is worth the daily UX improvement.
- **[Risk] List layout for a single profile may look sparse** → Trade-off: The profile card is designed to be visually substantial (shows calendars, event name, interval, status, inline actions). With "Quick Actions" and "Recent Activity" cards below, the page has enough content even with one profile.
- **[Risk] `DynamicColorBuilder` wrapping the `PermissionGate` may cause a visible theme flash if the gate shows before the app** → Mitigation: The gate already shows a loading indicator while checking permissions; dynamic color resolves synchronously, so no flash should occur.

## Migration Plan

1. Add `dynamic_color` to `pubspec.yaml` and run `flutter pub get`
2. Replace the `_SyncedApp` root with `DynamicColorBuilder` wrapping both `PermissionGate` and the main app
3. Create `lib/screens/dashboard_screen.dart` with profile list, quick actions, and recent activity
4. Create `lib/screens/profile_config_screen.dart` by extracting the config form from `HomePage`
5. Update `main.dart` to use `DashboardScreen` as the home instead of `HomePage`
6. Create shared widgets in `lib/widgets/`
7. Replace hardcoded colors throughout
8. Add `EmptyState` to `SyncStatusScreen`, `DryRunScreen`, and `DashboardScreen`
9. Run `flutter analyze` and manual testing on device

No database migration. No settings migration. Rollback is a simple `git revert`.

## Open Questions

- Whether to collapse completed sync config sections — deferred; can be addressed in a follow-up iteration
- Whether to add a "pull to refresh" on the Dashboard or status screen — deferred; out of scope for this change
- Whether the profile card should be tappable as a whole or only via an explicit "Configure" button — resolve during implementation
