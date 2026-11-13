# Design: Sync recurring events as independent instances

## Context

The sync engine (`lib/sync/sync_engine.dart`) today mirrors a recurring source event as **one recurring target event**: `_classify` detects instances (`eventId != instanceId`), fetches the master via `getEvent`, and creates a target event copying the `recurrenceRule` (`_execute`, `createEvent(recurrenceRule: ...)`). One mapping row covers the whole series, and `canonical_time` (`HH:mm` of the first instance) detects time-of-day changes.

This model loses per-occurrence exceptions. If the user moves one instance of the source series (or deletes one), the master is unchanged: `getEvent(master)` returns the original rule, `canonical_time` matches, and nothing happens — the exception is invisible in the target.

`device_calendar_plus` (Android) already expands series for us: `listEvents` queries `CalendarContract.Instances`, returning one `Event` per occurrence sharing the series `eventId` with a distinct `instanceId = "$eventId@$rawStart"` (start millis). Exceptions are respected by the system provider — a moved occurrence appears at its new time with a new `instanceId`; a deleted occurrence simply disappears.

`listEvents` currently hardcodes a 30-day window (`calendar_service.dart`).

## Goals / Non-Goals

**Goals:**

- Every occurrence of a recurring source event in the sync window becomes an independent, non-recurring target event.
- Moved or deleted occurrences in the source are reflected in the target (delete + create converges).
- Per-profile sync window (1/3/6/12 months) replaces the fixed 30 days.
- One-to-many mappings, keyed by `(source_event_id, source_instance_id)`, keep duplicates away.
- Legacy synced series migrate transparently on the first sync after upgrade.

**Non-Goals:**

- Past occurrences are never backfilled (listing starts at `now`, regardless of window).
- No RRULE expansion on the Dart side; we rely on the provider's `Instances` expansion.
- No batch API for mass creation; per-instance `createEvent` calls are accepted.
- Window changes do not retroactively delete or create; they take effect on the next sync.

## Decisions

### D1: Replace behavior — every listed occurrence is classified independently

The `eventId != instanceId` special case in `_classify` is removed. Each row of `listEvents` is classified on its own: recurring occurrences are treated exactly like single events, except `recurrenceRule` is never passed to `createEvent` (always a standalone target event).

- Classification key becomes `(eventId, instanceId)` instead of `eventId`.
- The master is **not** fetched in the happy path (no more `getEvent` per series for the RRULE). The only place that still fetches the master is orphan processing (D3).

**Alternatives considered:** keep a "recurring mode" toggle per profile — rejected; user wants full replacement, simpler surface.

### D2: Mapping keyed by instance — schema v9

`sync_mappings` gains a nullable `source_instance_id TEXT` column and the uniqueness constraint becomes:

```
UNIQUE(profile_id, source_calendar_id, source_event_id, source_instance_id)
```

- Non-recurring events keep `source_instance_id = NULL` (one row, as before).
- Occurrences store the plugin's `instanceId` (`eventId@BEGIN`). It is deterministic on Android and stable while the occurrence does not move — which is exactly the semantics we want: a moved occurrence gets a new key (old key becomes orphan, new key creates).

`canonical_time` is dropped from the engine logic for recurring events (kept as a nullable column for backwards compatibility only; no longer written). Per-occurrence change detection compares `startDate`/`endDate` millis directly — an occurrence whose time changed also changed `instanceId`, so the move is handled as orphan+create rather than update.

Migration to v9 follows the v4 pattern (table rebuild) because SQLite cannot alter a UNIQUE constraint in place. New columns on `sync_profiles`: `sync_window_days INTEGER NOT NULL DEFAULT 30`.

### D3: Per-occurrence orphan processing

For mappings whose `(eventId, instanceId)` did not appear in the listing:

```
target event missing               → remove mapping + created_events row
target ended > 7 days ago          → keep (past occurrences are never touched)
master still exists (getEvent)     → occurrence was moved/deleted as exception
                                      → delete target event + mapping
master gone                        → whole series deleted
                                      → delete target event + mapping
```

The "master still exists" check keeps the current semantics for whole-series deletion while making single-occurrence exceptions converge: the moved occurrence is deleted from its old slot (orphan) and created at its new slot (new key, unmapped → toCreate).

**Window roll-off is the tricky case** and is handled by the 7-day grace on the **target** event's end time: an occurrence that simply aged out of the window has a target event in the past (or just happened), so it is kept, not deleted. This mirrors the existing `_processOrphanMappings` behavior, now per occurrence.

### D4: Lazy migration of legacy series mappings

Upgrading users have 1-row mappings pointing at recurring target series. On the first sync after upgrade, the engine detects a legacy mapping: a row with `source_instance_id IS NULL` whose source `eventId` appears in the listing as a recurring instance (`eventId != instanceId`). For that series, the old target event (the recurring series) is deleted and the mapping row is removed; the listed occurrences then sync as independent events.

This happens during classification, before create/update classification of the series' occurrences, so no duplicate target events are produced. Non-recurring legacy mappings (NULL instance id, source not recurring) are untouched — they are already correct.

**Alternatives considered:** mass deletion of all mappings at upgrade — rejected (would orphan unrelated state and touch profiles that never had recurring events); keeping legacy series until the source changes — rejected (mixed behavior is confusing and the user chose full replacement).

### D5: Window selector per profile

`SyncProfile` gains `syncWindowDays` (30/90/180/365, default 30). Stored as `sync_window_days` in `sync_profiles`. The profile form's Advanced section gains a dropdown ("1 month", "3 months", "6 months", "1 year").

`CalendarService.listEvents(calendarId, {DateTime? end})` gains an optional end; the engine passes `now + window`. The sync task (foreground and background) reads the window from the profile.

**Alternatives considered:** global app setting — rejected (profiles already carry per-pair settings; different pairs may need different horizons).

## Risks / Trade-offs

- **[Target clutter]** A daily series with a 1-year window materializes ~365 target events and ~365 mapping rows, and the first sync performs ~365 `createEvent` calls. → Accepted; each call is a provider insert. UI (dry run, status) will list many items; the dry-run screen may need pagination later (not in scope).
- **[Sync liveness]** With instance sync, future occurrences only exist if the sync keeps running (WorkManager). If the app is dormant past the window, occurrences are never materialized. → The window selector is the user's control: longer windows trade clutter for resilience. Documented in UI copy.
- **[Delete/create churn on series edits]** Changing the series time-of-day moves every future occurrence (`instanceId` changes) → mass orphan-delete + create. → Correct but chatty; accepted. Moved single occurrences are the primary use case and converge the same way.
- **[Orphan rule false positives]** If the grace rule is wrong, past target events could be deleted on every sync (or stale events kept forever). → Covered by tests replicating: aged-out occurrence, moved occurrence, deleted occurrence, deleted series.
- **[instanceId instability across providers]** The plugin documents instance IDs as unstable when occurrences move. On Android it is `eventId@BEGIN` (deterministic). The app targets Android only. → Accepted; a moved occurrence is treated as delete+create, which is the desired outcome anyway.
- **[Migration safety]** Lazy migration deletes the old recurring target series on first sync. If deletion fails, mapping cleanup must not remove the mapping (retry next cycle). → Reuse existing soft-delete flow with verification; migration code paths get dedicated tests.

## Migration Plan

- Ship schema v9 (`source_instance_id`, new UNIQUE, `sync_window_days`) with table rebuild for `sync_mappings` (pattern of v4) and `ALTER TABLE` for profiles.
- No destructive migration at upgrade time; legacy series mappings convert lazily on each profile's first post-upgrade sync (D4).
- Rollback: the app is not versioned with rollback expectations; if a rollback were needed, old binaries read the old schema (v9 rebuild is forward-only). Downgrading is not supported.
