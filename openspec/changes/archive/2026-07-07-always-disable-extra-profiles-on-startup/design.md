## Context

Two remaining gaps after the `disable-profiles-on-subscription-expiry` fix:

```
  Gap 1 — Startup #2+ (já expirado):
  ┌─────────────────────────────────────────┐
  │ entitled: false (prefs)                 │
  │ query: false                            │
  │ false → false → NADA ✗                  │
  │ handleSubscriptionExpired NUNCA roda    │
  │ profiles extras continuam enabled ✗     │
  └─────────────────────────────────────────┘

  Gap 2 — Usuário nunca mais abre o app:
  ┌─────────────────────────────────────────┐
  │ Play Store: cancelada                   │
  │ App: fechado, ninguém sabe              │
  │                                         │
  │ Background sync a cada 15min:           │
  │   lê prefs → true                       │
  │   canProfileSync(true, 1) → true        │
  │   sync roda normalmente ✗               │
  │                                         │
  │   NUNCA consulta Play Store!            │
  └─────────────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**
- Ensure `handleSubscriptionExpired` runs on every startup when not subscribed (Gap 1)
- Periodically verify subscription state from Play Store in background (Gap 2)
- Fall back to cached SharedPreferences value when Play Store query fails

**Non-Goals:**
- Changing `handleSubscriptionExpired` or any other entitlement function
- Modifying the sync gate logic
- Changing fdroid behavior (always `isSubscribed = true`)

## Decisions

### Decision 1: Unconditional `handleSubscriptionExpired` on startup

```dart
// main.dart, after subscriptionService.initialize():
if (!subscriptionService.isSubscribed) {
  final profileService = ProfileService();
  await handleSubscriptionExpired(profileService);
}
```

Idempotent: returns immediately if `profiles.length <= 1`, only disables enabled profiles.

### Decision 2: Background entitlement check with 24-hour TTL

The background sync task checks subscription state from Play Store once every 24 hours. Between checks it uses the cached SharedPreferences value. On query failure, it keeps the current cached value (never blocks sync).

```
  Background sync executa:
  ┌─────────────────────────────────────┐
  │ last_entitlement_check < 24h?       │
  │   ├─ Sim → usa cache (prefs)        │
  │   └─ Não → queryPastPurchases()     │
  │            ├─ Sucesso → atualiza    │
  │            │   prefs + timestamp    │
  │            └─ Falha → usa cache     │
  └─────────────────────────────────────┘
```

**Why 24 hours**: Play Store subscriptions typically change on a monthly/yearly cycle. A 24-hour delay in detection is acceptable. 1 network call per day per device is negligible.

**Alternatives considered:**
- Every sync execution (~15 min): ~96 calls/day, excessive and unnecessary
- Separate WorkManager task: adds complexity, two tasks to manage

### Decision 3: Static `queryBackgroundEntitlement()` function per flavor

A top-level function in each flavor's `subscription_service.dart`:

**fdroid** (`subscription_service.dart`):
```dart
Future<bool> queryBackgroundEntitlement() async => true;
```

**gplay** (`subscription_service_gplay.dart`):
```dart
Future<bool> queryBackgroundEntitlement() async {
  try {
    // queryPastPurchases() ...
    // if found active sub → return true
  } catch (_) {}
  // fallback to cached value
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('subscription_entitled') ?? false;
}
```

`sync_task.dart` imports this function and calls it when the TTL expires. The function is self-contained — no dependency on `WidgetsBinding`, `InAppPurchase.instance`, or the main isolate's `subscriptionService`.

**Why a free function, not a static method**: Each flavor replaces the entire file, so it's safe. No import of `in_app_purchase_android` leaks into fdroid.

## Risks / Trade-offs

- **Up to 24h detection delay**: Subscription cancelled today, background sync continues until tomorrow's check. Acceptable trade-off for 1 call/day.
- **`queryPastPurchases` may not work in background isolate**: If the `in_app_purchase_android` plugin doesn't initialize its method channel in the WorkManager isolate, the query will fail. The fallback to cache ensures sync isn't blocked — it just won't detect the cancellation until the next time the user opens the app.
- **Double call on first expiry startup**: Both `onStatusChanged(false)` and the unconditional startup call fire. Idempotent — second call is a no-op.
