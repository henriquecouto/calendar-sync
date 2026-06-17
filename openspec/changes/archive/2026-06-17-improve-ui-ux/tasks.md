## 1. Setup

- [x] 1.1 Add `dynamic_color` dependency to `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` to install the new dependency

## 2. Theme Infrastructure

- [x] 2.1 Replace static `ColorScheme.fromSeed` in `_SyncedApp` with `DynamicColorBuilder` wrapping the entire app
- [x] 2.2 Implement `onLight` callback that returns `ThemeData` from the dynamic light `ColorScheme`
- [x] 2.3 Implement `onDark` callback that returns `ThemeData` from the dynamic dark `ColorScheme`
- [x] 2.4 Set both `theme` and `darkTheme` on `MaterialApp` so it auto-switches with system brightness

## 3. Shared Widgets

- [x] 3.1 Create `lib/widgets/profile_card.dart` — card widget showing source→target, event name, interval, enabled status, last sync time, with inline sync and configure actions
- [x] 3.2 Create `lib/widgets/sync_plan_card.dart` — unified card widget for sync plan entries (create, update, delete, skip, error) with icon, label, and semantic color
- [x] 3.3 Create `lib/widgets/empty_state.dart` — reusable empty-state placeholder with icon, title, and optional subtitle
- [x] 3.4 Create `lib/widgets/section_header.dart` — section label widget for grouping entries in dry-run and status screens

## 4. Dashboard Screen

- [x] 4.1 Create `lib/screens/dashboard_screen.dart` as the new home screen
- [x] 4.2 Implement profile list area using `ProfileCard` widget (scrollable list, currently one item)
- [x] 4.3 Implement Quick Actions section with "Sync All" and "Dry Run" buttons
- [x] 4.4 Implement Recent Activity section showing last few sync runs from `MappingDatabase`
- [x] 4.5 Add "View full history" link that navigates to `SyncStatusScreen`
- [x] 4.6 Add empty state when no profile is configured ("No sync profiles yet" + "Create Profile" action)
- [x] 4.7 Disable Quick Action buttons when no profile exists

## 5. Profile Config Screen

- [x] 5.1 Create `lib/screens/profile_config_screen.dart` by extracting the config form from `HomePage`
- [x] 5.2 Organize controls into semantic cards: Calendar Pairing (source/target dropdowns), Event Naming (text field), Schedule (interval + toggle)
- [x] 5.3 Add calendar loading state for dropdowns while fetching
- [x] 5.4 Add empty state for dropdowns when no calendars available
- [x] 5.5 Wire save logic (persist via `SettingsService`) on pop or explicit save

## 6. Update Main Entry Point

- [x] 6.1 Update `main.dart` to use `DashboardScreen` as the home instead of `HomePage`
- [x] 6.2 Wire `DynamicColorBuilder` into the app root (wrap both `PermissionGate` and `_SyncedApp`)
- [x] 6.3 Keep `PermissionGate` as the root widget and ensure it inherits the dynamic theme

## 7. Update Existing Screens

- [x] 7.1 Update `lib/sync/dry_run_screen.dart` to use shared `SyncPlanCard`, `SectionHeader`, and `EmptyState` widgets instead of private `_CreateTile`, `_UpdateTile`, etc.
- [x] 7.2 Update `lib/sync/sync_status_screen.dart` to use `EmptyState` when no sync history exists
- [x] 7.3 Update `lib/permissions/permission_gate.dart` to use `colorScheme` for its buttons, text, and background

## 8. Replace Hardcoded Colors

- [x] 8.1 Search and replace `Colors.red` with `colorScheme.error` in all widgets
- [x] 8.2 Search and replace `Colors.green` with `colorScheme.primary` in all widgets
- [x] 8.3 Search and replace `Colors.orange` with `colorScheme.tertiary` in all widgets
- [x] 8.4 Search and replace `Colors.grey` with `colorScheme.outline` or `colorScheme.surfaceVariant` as contextually appropriate
- [x] 8.5 Remove the hardcoded `Colors.deepPurple` seed — it is no longer needed (kept only as fallback in `DynamicColorBuilder` for unsupported platforms)

## 9. Verification

- [x] 9.1 Run `flutter analyze` and fix any warnings or errors
- [x] 9.2 Run `flutter test` and ensure all existing tests pass
- [x] 9.3 Manually verify light theme renders correctly on all screens
- [x] 9.4 Manually verify dark theme renders correctly on all screens
- [x] 9.5 Manually verify permission gate screen uses dynamic colors
- [x] 9.6 Manually verify empty states display on Dashboard (no profile), sync status, and dry-run screens
- [x] 9.7 Manually verify navigation flow: Dashboard → ProfileConfig → back, Dashboard → DryRun → back, Dashboard → SyncHistory → back
