## Context

The sync engine currently formats every target event's description as:

```
<original source title>
---
🔃 Automatically created by CalSync
```

…optionally prepending the source event's description when the profile's `copyDescription` toggle is on. The first line is the *source* event title — not the profile's user-configured `syncEventName`. For users syncing a personal calendar to a work calendar to block out busy time, this means the personal event title (e.g. "Doctor Appointment") ends up in the work calendar's event description, where coworkers may be able to see it. The existing `syncEventName` field already lets users replace the *title* of the synced event with a generic value (e.g. "Busy"), but there is no equivalent privacy control over the description.

The proposal is to add a profile-level `omitSourceTitle` boolean (default `false`, preserving current behavior). When on, the source event's title is **replaced** by a full SHA256 fingerprint (64 hex characters) of the title — non-reversible, but deterministic. The fingerprint lives in the same position as the title would, so the sync engine can still detect when the source title changes (the fingerprint changes too) without ever revealing the title itself in the work calendar.

Description format by flag combination:

```
┌──────────────────┬─────────────────┬──────────────────────────────────┐
│ omitSourceTitle │ copyDescription │ Target description             │
├──────────────────┼─────────────────┼──────────────────────────────────┤
│ false (default) │ false           │ <title>\n---\n🔃...             │
│ false           │ true            │ <src desc>\n\n<title>\n---\n🔃..│
│ true            │ false           │ <sha256>\n---\n🔃...            │
│ true            │ true            │ <src desc>\n\n<sha256>\n---\n🔃..│
└──────────────────┴─────────────────┴──────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**
- Add an `omitSourceTitle` boolean to the `SyncProfile` model, schema, form, and sync engine
- When enabled, replace the source title in the target event's description with a non-reversible SHA256 fingerprint while keeping the sync marker
- Compose correctly with `copyDescription` and `copyLocation` (independent toggles)
- Detect title changes via the SHA256 fingerprint so already-synced events still get updated when the source title changes (and get cleaned up the first cycle after the flag is flipped on)
- Persist the setting across app restarts

**Non-Goals:**
- Removing the source title from the target event's *title* field (this is already controlled by `syncEventName`)
- A UI for previewing what the synced event will look like
- Server-side filtering — this is purely local description formatting
- Changing the sync marker string itself
- Truncating the SHA256 fingerprint — full 64 chars is used (collision risk is mathematically zero for short titles)

## Decisions

### Extend `buildDescription()` to accept `omitSourceTitle`

Current signature (top of `lib/sync/sync_engine.dart`):
```dart
String buildDescription(
  String originalTitle,
  String? sourceDescription,
  bool copyDescription,
)
```

New signature:
```dart
String buildDescription(
  String originalTitle,
  String? sourceDescription,
  bool copyDescription, {
  bool omitSourceTitle = false,
})
```

Behavior:
- `omitSourceTitle: false` → existing format (`<title>\n---\n<marker>`, optionally prepended source description) — unchanged from today
- `omitSourceTitle: true` → title line is replaced by `sha256.convert(originalTitle.codeUnits).toString()` (lowercase hex, 64 chars); `---` separator stays so the visual structure of the description is preserved; result is either `<sha256>\n---\n<marker>` or `<source description>\n\n<sha256>\n---\n<marker>` when `copyDescription` is also enabled with a non-empty source description

The SHA256 fingerprint is deterministic — same input always produces same output — but one-way. It is used purely as a change-detection signal by the sync engine; it is not user-facing privacy infrastructure (the title is the privacy concern, not the hash).

This is a non-breaking change because the new parameter is optional with a default that reproduces current behavior.

### Thread the flag through `SyncEngine`

`runSync`, `runDryRun`, `_classify`, `_classifySingle`, and `_execute` all gain an `omitSourceTitle` parameter (default `false`). Call sites in `dashboard_screen.dart`, `sync_task.dart`, and `dry_run_screen.dart` read the value from the loaded `SyncProfile` and pass it through. No new public-API surface beyond the additional named parameter.

### Update change-detection in `_classifySingle`

The current logic (line ~351) uses:
```dart
final titleChanged =
    !(targetEvent.description?.contains(event.title) ?? false);
```
to detect when the target description is out of date. Naively inverting this when `omitSourceTitle: true` would be wrong (false positives on empty titles and on title-as-substring of copied descriptions). Instead, change-detection is **mode-aware**: the title comparison switches between two `contains`-style checks depending on `omitSourceTitle`.

```dart
final titleFingerprint = omitSourceTitle
    ? sha256.convert(event.title.codeUnits).toString()
    : event.title;
final titleChanged =
    !(targetEvent.description?.contains(titleFingerprint) ?? false);
```

Properties of this approach:
- **Default mode** (`omitSourceTitle: false`) — existing `contains(title)` semantics preserved exactly. Robust to calendar-provider HTML wrapping (the title text survives wrapping); tolerates substring matches in the source description.
- **Privacy mode** (`omitSourceTitle: true`) — `contains(sha256(title))` is robust to HTML wrapping (the hash is ASCII and survives wrapping) AND robust to substring collisions (a 64-char hex string is effectively unique across calendar titles, so it won't appear coincidentally anywhere else in the description).
- **Migration case** — toggling `omitSourceTitle` from `false` to `true` on an already-synced profile: the existing target description contains the plaintext title but no SHA256 fingerprint, so `contains(sha256(title))` returns `false` → `titleChanged = true` → engine creates a replacement event whose description has the fingerprint instead. One-time cleanup cost, then stable. Toggling back `true → false` produces the symmetric cleanup.
- **Empty source title edge case** — `sha256('')` is a well-known constant (`e3b0c44...`), so `contains(constant)` works correctly without special-casing.
- **Title change detection** — when the source title changes from "Doctor" to "Doctor2", `sha256(title)` changes → `contains(sha256("Doctor2"))` returns false against an old target that has `sha256("Doctor")` → `titleChanged = true` → update.

`descriptionChanged` (for `copyDescription: true`) continues to use the existing `contains(sourceDescription)` approach (already used in tests today). `timeChanged` is unchanged. Final update decision: `timeChanged || titleChanged || descriptionChanged`.

### Database schema bump (v7 → v8)

Add `omit_source_title INTEGER NOT NULL DEFAULT 0` to the `sync_profiles` table. The `onUpgrade` callback adds a new branch for `oldVersion < 8` that runs `ALTER TABLE sync_profiles ADD COLUMN omit_source_title INTEGER NOT NULL DEFAULT 0`. Existing rows default to `0` (off), which preserves current behavior — no migration of existing synced target events is needed at the database layer; the sync engine will detect format mismatches on the next cycle and update them.

The SHA256 fingerprint is **not persisted** in the database. It is recomputed on every sync cycle from the live source event. This keeps the mapping table and target events independent of any one-way-hash state — no risk of stale hashes.

### Form changes in `profile_config_screen.dart`

Add a new `SwitchListTile` titled "Omit source event title" with a hint explaining the privacy use case (e.g. "Hide the original event title from the synced event's description — only a non-reversible fingerprint is stored"). The toggle goes inside the existing Advanced `ExpansionTile`, after the existing copy toggles. Update the `advancedExpanded` derivation so the Advanced section auto-expands when editing a profile that has `omitSourceTitle: true`.

Add a `_omitSourceTitle` state field, populate it from the loaded profile in `_load()`, and pass it to `createProfile` / `updateProfile`.

### ProfileService model extension

`SyncProfile` gains an `omitSourceTitle` field defaulting to `false`. `copyWith`, `createProfile`, `updateProfile`, and `_rowToProfile` all gain the new field, mirroring the existing `copyDescription` / `copyLocation` plumbing exactly. The new column constant `_columnOmitSourceTitle = 'omit_source_title'` is added.

### Add `crypto` dependency

`crypto: ^3.0.0` (Dart team, pure Dart, no platform code, F-Droid compatible) added to `dependencies` in `pubspec.yaml`. The package is shared across both build flavors (fdroid and gplay) so it lives in the base pubspec only — `pubspec_gplay.yaml` is an overlay file containing only gplay-only deps (`in_app_purchase`, `url_launcher`) and should not duplicate shared dependencies.

## Risks / Trade-offs

- [Risk] Existing profiles created before v8 default to `omitSourceTitle: false` → silently keep leaking title in description. → Mitigation: documented behavior; the change is opt-in. Existing users who want privacy can flip it on.
- [Risk] Toggling `omitSourceTitle: true` for an already-synced profile causes N replacement event creates + deletes on the next sync cycle. → Mitigation: expected behavior; the change-detection logic does the right thing (existing targets lack the SHA256 fingerprint → `contains` returns false → replacement). Workmanager background sync handles it incrementally.
- [Risk] SHA256 collision in the change-detection `contains` check. → Mitigation: collision probability for short titles (< 256 chars) is mathematically zero (~ 1 in 2^256). Even if a collision somehow occurred, the worst case is one missed update, then re-sync on the next cycle would still re-classify via the time check.
- [Risk] Adding a hash line to the description is itself a small piece of metadata visible in the work calendar. → Mitigation: this is the cost of preserving change-detection in privacy mode. Users who want ZERO metadata can layer this with `copyDescription: false` to get just the marker line + hash line. Documented in the form's hint text.
- [Trade-off] The `---` separator is kept (not dropped) when `omitSourceTitle: true`. Even though there's no title above it, keeping the separator preserves the visual structure of the description and gives the SHA256 line a clear "header" position relative to the marker.
- [Trade-off] The default mode is unchanged (still contains plaintext title), which means the SHA256 fingerprint only appears when `omitSourceTitle: true`. This is intentional — the hash is a privacy-mode-only artifact, not a universal addition.

## Migration Plan

1. Database schema version bumps 7 → 8 with `ALTER TABLE sync_profiles ADD COLUMN omit_source_title INTEGER NOT NULL DEFAULT 0`
2. No data backfill required — the sync engine detects stale descriptions on the next cycle and updates them when `omitSourceTitle: true` is enabled
3. No changes to mapping table, sync status table, or sync_created_events table
4. Rollback: ship a follow-up that reverts the version bump; new column will simply be ignored by older builds (sqflite's `ALTER TABLE ADD COLUMN` is forward-compatible with older readers as long as they don't try to write the column)

## Open Questions

None — the design fits cleanly into the existing patterns established by `copyDescription` / `copyLocation`.