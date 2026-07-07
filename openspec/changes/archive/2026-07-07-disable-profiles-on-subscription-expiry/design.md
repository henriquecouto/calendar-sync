## Context

```
   Cold start after subscription expiry
   ──────────────────────────────────────
   
   GplaySubscriptionService created
   ┌─────────────────────────────────┐
   │  bool entitled = false;         │  ← SEMPRE. In-memory field.
   └─────────────────────────────────┘
   
   initialize() → _querySubscriptionStatus()
   
   ┌──────────────────────────────────────────────┐
   │  final previous = entitled;  // = false      │
   │  entitled = hasActiveSub;    // = false      │
   │                                              │
   │  if (previous != entitled)                   │
   │    false != false → NÃO EXECUTA              │
   │                                              │
   │  → onStatusChanged NUNCA dispara             │
   │  → handleSubscriptionExpired NUNCA roda      │
   │  → profiles extras continuam enabled no BD   │
   │  → Sync All sincroniza tudo                  │
   └──────────────────────────────────────────────┘
```

The `entitled` field is ephemeral. On every cold start it resets to `false`, so the `true→false` transition (subscription expired while app was closed) is invisible to the service. The `onStatusChanged` callback — which triggers `handleSubscriptionExpired` — never fires because `previous` and `current` are both `false`. This is the root cause of the bug.

Beyond the cold start, the sync execution layer has no independent subscription check. It trusts that `handleSubscriptionExpired` has already disabled extra profiles in the database. This lack of defense-in-depth means any failure in the primary mechanism allows extra profiles to sync indefinitely.

The app uses Flutter's `WorkManager` plugin, which runs background tasks in a separate isolate. The global `subscriptionService` instance is only accessible from the main isolate.

## Goals / Non-Goals

**Goals:**
- Fix the primary bug: persist `entitled` to SharedPreferences so cold starts correctly detect `true→false` transitions and trigger `handleSubscriptionExpired`
- Add defense-in-depth: a subscription check at every sync execution path so extra profiles are skipped even if the database-level disable fails
- Centralize the "can this profile sync?" decision in a single pure function
- Make the subscription state available to background isolates via SharedPreferences
- Keep the sync engine decoupled from subscription concerns

**Non-Goals:**
- Changing the primary enforcement mechanism (database `enabled` flag)
- Modifying how the gplay service queries the Play Store
- Changing the fdroid flavor behavior (fdroid always returns `isSubscribed = true`, so the gate never blocks)
- Adding subscription checks to the sync engine internals — the gate is at the caller level

## Decisions

### Decision 1: Persist and restore `entitled` in GplaySubscriptionService itself

The `GplaySubscriptionService` writes `entitled` to SharedPreferences every time it changes (in `_querySubscriptionStatus` and `_onPurchaseUpdate`). On `initialize()`, before querying the Play Store, it reads the persisted value to restore the last known state. This makes `previous != current` detectable across cold starts.

The key is `subscription_entitled` (same key consumed by background isolates and the sync gate).

**Alternatives considered:**
- Write from `main.dart` `onStatusChanged` callback: too late — by the time the callback fires, the database disable has already happened (or not, due to the bug). The service itself must know its prior state before the comparison.
- Store in SQLite instead of SharedPreferences: overkill for a single boolean. SharedPreferences is simpler and already used by the app.

### Decision 2: Gate at call sites, not in SyncEngine

`SyncEngine.runSync()` remains unaware of subscriptions. Instead, each caller (dashboard, Sync All, background task, dry run, scheduler) checks `canProfileSync` before invoking the engine. This keeps the sync engine testable in isolation and avoids coupling the engine to the subscription domain.

**Alternatives considered:**
- Check inside `runSync()`: would centralize the logic but pollutes the engine with a cross-cutting concern and makes unit tests harder
- Check inside `listEnabledProfiles()`: introduces side effects in a data access method; rejected because query methods shouldn't filter by business rules

### Decision 3: `canProfileSync(isSubscribed: bool, profileIndex: int)` pure function

A stateless function that returns `true` if `isSubscribed` is `true` OR `profileIndex == 0`. This is trivially testable and can be called from any context as long as a `bool` is available.

**Alternatives considered:**
- `canProfileSync(subscriptionService)` — requires access to the full service object, impossible from background isolates
- Store and read from SharedPreferences inside the function — adds I/O to what should be a fast synchronous check at multiple call sites

### Decision 4: Sync Scheduler excludes non-syncable profiles when computing min interval

`SyncScheduler.updatePeriodicTask()` must exclude extra profiles from the minimum interval calculation when the user is not subscribed. Otherwise the periodic task would be registered with an extra profile's interval but would skip it at execution time — resulting in wasted wake-ups.

The scheduler is called from the main isolate and has access to `subscriptionService.isSubscribed`, so no SharedPreferences reading is needed here.

## Risks / Trade-offs

- **SharedPreferences coupling in GplaySubscriptionService**: The service now depends on `shared_preferences`. This is acceptable — the app already uses the package, and the service is already platform-specific (Android-only IAP).
- **Persisted state may lag one cycle**: If the Play Store query succeeds but SharedPreferences write fails, the next cold start will use the previous value. Mitigation: write SharedPreferences before the comparison in `_querySubscriptionStatus`, so even on write failure the comparison is still correct for the current session.
- **Sync Scheduler reads from main isolate subscriptionService**: If the scheduler is called before `subscriptionService.initialize()` completes, `isSubscribed` may return the default `false`. This could temporarily cancel the periodic task. Mitigation: the scheduler already has safeguards (no profiles → cancel task), and it's re-called whenever profiles change, so it self-corrects.
