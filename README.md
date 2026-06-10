# CalSync

![CalSync Icon](assets/icon.svg)

**Sync events across multiple local device calendars on Android.**

When an event appears in your source calendar, CalSync automatically creates a corresponding event in your target calendar using a custom name you provide — perfect for marking "Busy", "Out of Office", or any custom status across calendars.

---

## Features

- **Cross-calendar sync** — Mirror events from one local calendar to another
- **Custom event names** — Synced events use your chosen name (not the original title)
- **Duplicate prevention** — Local mapping table tracks `(source_event_id, source_calendar_id) → (target_event_id, target_calendar_id)`
- **Reactive + periodic sync** — Instant reaction to calendar changes via Android observer, with configurable fallback interval
- **Background execution** — Uses `WorkManager` for reliable background sync
- **Permission handling** — Runtime requests for `READ_CALENDAR`, `WRITE_CALENDAR`, `POST_NOTIFICATIONS`

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart) |
| Calendar Access | `device_calendar` |
| Permissions | `permission_handler` |
| Persistence | `shared_preferences` + `sqflite` |
| Background Work | `workmanager` |
| Build | Gradle (CLI) |

---

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Source Calendar│────▶│   Sync Engine    │────▶│ Target Calendar │
└─────────────────┘     └────────┬─────────┘     └─────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Mapping Database      │
                    │ (source_id, cal_id) →   │
                    │ (target_id, cal_id)     │
                    └─────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Background Workers     │
                    │  • Reactive (observer)  │
                    │  • Periodic (fallback)  │
                    └─────────────────────────┘
```

**Key components:**
- `SyncEngine` — Orchestrates reading source events, checking mapping DB, creating/updating/deleting target events
- `MappingDatabase` — SQLite table persisting sync relationships across app restarts
- `CalendarService` — Wrapper around `device_calendar` plugin
- `SettingsService` — Persists user config (calendar IDs, sync name, interval)
- `PermissionGate` — Blocks UI until calendar permissions granted

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.12.1
- Android SDK (API 33+ recommended)
- Physical device or emulator with Google Play Services

### Install & Run
```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run tests
flutter test

# Static analysis
flutter analyze
```

---

## Configuration

On first launch, CalSync requests calendar permissions. Then configure:

1. **Source Calendar** — Where events originate
2. **Target Calendar** — Where synced events are created
3. **Sync Event Name** — Custom title for synced events (e.g., "Busy", "Focus Time")
4. **Fallback Interval** — Periodic sync backup (default: 1 hour; set to 0 for manual only)

> Changes are detected reactively within seconds. The interval is a fallback only.

---

## How It Works

### Sync Detection
CalSync does **not** rely on event ID equality across calendars (IDs are per-provider). Instead:
1. On each sync, read all events from source calendar since last sync
2. For each source event, check mapping DB: `(source_event_id, source_calendar_id)`
3. If mapping exists → update target event
4. If mapping missing → create target event with custom name, store mapping
5. If target event exists but source deleted → delete target, remove mapping

### Triggers
- **Reactive**: Android calendar content observer → `WorkManager` one-off task (5s delay)
- **Periodic**: Configurable `WorkManager` periodic task (fallback)

---

## Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/` or `build/app/outputs/bundle/`

---

## License

[GPL-3.0](LICENSE) © Henrique Couto
