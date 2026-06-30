## Context

Currently, every sync profile requires a user-provided `eventName` string. The sync engine uses this string as the title of every target event it creates, while the original source event title goes into the description (alongside the sync marker). The `event_name` column is `TEXT NOT NULL DEFAULT ''` and is validated as required in the UI (`'Event name is required'`) and guarded at sync time (both manual and background skip empty names).

## Goals / Non-Goals

**Goals:**
- Make `eventName` optional: empty means "use the source event's original title"
- Sync engine uses `event.title` as target event title when `eventName.isEmpty`
- Sync guards (dashboard, background) no longer skip profiles with empty `eventName`
- Backward compatible — existing profiles have non-empty `eventName` and work identically

**Non-Goals:**
- Adding new DB columns or schema migrations
- Adding new UI toggles or switches
- Changing the description format (source title + sync marker)
- Retroactively updating existing synced events

## Decisions

### Decision 1: Empty eventName = use original title

Instead of adding a separate boolean flag, the `eventName` field's emptiness carries the semantics: filled = custom name, empty = original title. No DB migration needed because `event_name` already defaults to `''`.

**Rationale**: The two modes (custom name vs. original title) are mutually exclusive. Using emptiness as the signal eliminates a new column, a migration, and a UI toggle. The hint text makes the behavior discoverable.

**Alternatives considered**:
- *Boolean `keepOriginalNames` flag* — Rejected. Requires DB migration, new column, extra UI toggle, and more conditional logic for no benefit over the empty-field approach.
- *Nullable eventName* — Rejected. Schema already uses `NOT NULL DEFAULT ''`; switching to nullable complicates deserialization for no gain.

### Decision 2: Relaxed validation on eventName

The existing validation at `ProfileConfigScreen._save()` forces `eventName` to be non-empty. This is removed — empty is now a valid state meaning "use original titles." The `_eventNameError` state is removed.

**Rationale**: The field is no longer required. Validation of other fields (profile name uniqueness, source ≠ target) is unchanged.

### Decision 3: Helper text below the field

A small helper text following the existing `Fallback Interval` pattern explains the behavior:

```dart
const SizedBox(height: 8),
Text(
  'Leave empty to keep original event titles.',
  style: TextStyle(fontSize: 12, color: colorScheme.outline),
),
```

The `hintText` on the `TextField` remains `'e.g. Busy'` for users who want a custom name.

**Rationale**: This pattern is already used for the fallback interval helper text (lines 410–417 of `profile_config_screen.dart`). Consistency with existing UI conventions.

### Decision 4: Sync engine title selection

In `SyncEngine._classifySingle()`, instead of always using `syncEventName`:

```dart
projectedTitle: syncEventName.isEmpty ? event.title : syncEventName,
```

No new parameter needed — `syncEventName` is already threaded through the engine. The `isEmpty` check on the existing string is sufficient.

**Rationale**: Minimal change. The decision is made at classification time, and the rest of the pipeline (`_execute`) is title-agnostic.

### Decision 5: Profile card display when empty

When `eventName` is empty, the profile card shows "Original titles" instead of an empty string or the raw event name. The `eventName` field on the card already uses `'"${profile.eventName}"'` formatting — this changes to show the fallback label.

**Rationale**: Displaying an empty string or `""` on the card is confusing. A clear label communicates the profile's behavior.

### Decision 6: Description format unchanged

The description remains `<source title>\n---\n🔃 Automatically created by CalSync` regardless. When `eventName` is empty, the title and first line of the description will match — this is harmless and preserves change-detection and loop-prevention.

## Risks / Trade-offs

- [Risk] If a user clears an existing `eventName`, the next sync updates all target events' titles to match source titles (via existing change-detection). → Mitigation: Expected behavior. The helper text makes this clear.
- [Risk] An empty `eventName` in old profiles (migrated from legacy, pre-profile versions) could now trigger syncs unexpectedly. → Mitigation: The legacy migration (`prefs.remove('sync_event_name')`) ran before profiles were introduced. No known profiles have empty `eventName` in practice due to UI validation.
- [Risk] Users may not realize empty = "keep original" without reading the helper text. → Mitigation: The profile card also shows "Original titles" when empty, reinforcing the behavior.
