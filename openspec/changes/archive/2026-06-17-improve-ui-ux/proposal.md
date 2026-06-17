## Why

The current UI is functional but feels like a dev tool rather than a polished app. All controls are crammed into a single scrollable column with no visual hierarchy, hardcoded colors bypass the M3 theme, there is no dark mode support, and the app ignores Android's Material You dynamic color system. Worse, the "home" screen is a configuration form — the user sees the same setup controls every time they open the app, even after everything is configured. The screens they actually want (sync history, dry run preview) are hidden behind tiny abstract icons in the app bar. This undermines user trust and adoption for what is otherwise a solid sync engine.

## What Changes

- **Dashboard replaces config as home**: A new Dashboard screen becomes the app's home, showing current sync profile status at a glance, quick actions (Sync All, Dry Run), and recent activity. Configuration moves to a separate `ProfileConfigScreen`.
- **Profile list structure from day one**: Even with a single profile today, the Dashboard uses a list layout so it will naturally support multiple sync profiles in the future without layout changes.
- **Material You dynamic color**: Replace the hardcoded `deepPurple` seed with system wallpaper-derived colors, adapting automatically to the user's device theme
- **Dark theme support**: Add `darkTheme` so the app follows the system light/dark setting
- **Extract reusable widgets**: Move inline card/tile widgets from `dry_run_screen.dart` and `main.dart` into a shared `lib/widgets/` directory for consistency and maintainability
- **Consistent theming throughout**: Replace hardcoded colors (`Colors.grey`, `Colors.red`, `Colors.green`, `Colors.orange`) with theme-derived colors so all screens respect the Material You palette
- **Improved empty/error/loading states**: Add meaningful placeholder UI for empty calendar lists, no profiles configured, no sync history, and dry-run results
- **Permission gate theming**: Apply the same Material You theme to the `PermissionGate` screen instead of using Flutter defaults

## Capabilities

### New Capabilities

- `material-you-theming`: Dynamic color extraction from the system wallpaper via Material You, with automatic light/dark mode following the device setting. Applies consistently across all screens including the permission gate.
- `ui-screen-composition`: Dashboard as the home screen with profile list, quick actions, and recent activity; extracted shared widgets for sync result tiles; ProfileConfigScreen extracted from the home; improved navigation with consistent app bar styling; meaningful empty/loading/error state UI across all screens.

### Modified Capabilities

<!-- No existing spec requirements change — this is purely a presentation-layer improvement -->

## Impact

- Affected files: `lib/main.dart` (theme + Dashboard replaces HomePage + new ProfileConfigScreen), `lib/permissions/permission_gate.dart` (theme), `lib/sync/dry_run_screen.dart` (extract shared widgets), `lib/sync/sync_status_screen.dart` (empty states)
- New files: `lib/screens/dashboard_screen.dart`, `lib/screens/profile_config_screen.dart`, `lib/widgets/profile_card.dart`, `lib/widgets/sync_plan_card.dart`, `lib/widgets/empty_state.dart`, `lib/widgets/section_header.dart`
- New dependency: `dynamic_color` Flutter package for Material You dynamic color extraction
- No change to sync engine, mapping database, calendar service, settings, or background sync logic
