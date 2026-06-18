## Context

The current `titleChanged` check uses `targetEvent.description.startsWith(event.title)`. This works for plain-text descriptions but breaks when Outlook converts the description to HTML:

```
Description saved by sync:
  "Doctor Appointment\n---\n🔃 Automatically created by CalSync"

Description after Outlook re-sync:
  "<html><body>Doctor Appointment<br>---<br>🔃 Automatically created by CalSync</body></html>"

startsWith("Doctor") → false → titleChanged = true → false UPDATE
```

Every sync cycle would detect a "title change" and recreate the target event.

## Goals / Non-Goals

**Goals:**
- Replace `startsWith` with `contains` for title comparison
- HTML-wrapped descriptions are correctly recognized as unchanged

**Non-Goals:**
- Stripping HTML tags (avoids dependency on an HTML parser)
- Changing the description marker detection (already uses `contains`)

## Decisions

### `contains` instead of `startsWith`
Switching to `targetEvent.description?.contains(event.title) ?? false`. This correctly matches `"Doctor Appointment"` inside both plain-text and HTML-wrapped descriptions.

Edge case: user renames event from "Doctor Appointment" to "Appointment" — `contains("Appointment")` matches the old HTML description too, skipping the update for one cycle. This is rare and self-corrects on the next cycle when the target description is overwritten with the new title.

### No HTML stripping
Stripping HTML would be more precise but adds dependency on an HTML parser and is unnecessary: `contains` handles both formats correctly. Stripping could also remove content if the provider wraps text differently.

## Risks / Trade-offs

- **Subtring match false positive**: `contains` could match a partial title substring (e.g., "Doctor" matching "Doctor Appointment"). This is identical to the `startsWith` risk and only delays the update by one cycle.
