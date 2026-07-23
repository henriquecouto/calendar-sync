## Context

The current `fastlane/metadata/android/en-US/` files have minimal, feature-list-only content with no store search optimization. Competing SaaS products (OneCal, CalendarBridge, Reclaim.ai) use keyword-dense titles, competitively-positioned descriptions, and name-check each other for search traffic. CalSync has unique architectural advantages (no internet permission, no data collection, open source, free) that are entirely absent from the listing.

F-Droid enforces a 30-character title limit; Google Play allows up to 50. The metadata must work for both stores identically.

## Goals / Non-Goals

**Goals:**
- Title under 30 characters with keyword-dense subtitle (F-Droid compatible)
- Short description under 80 characters packing key differentiators
- Full description leading with competitive positioning, use cases, and competitor name-checks
- Same metadata content for both F-Droid and Google Play (no store-specific variants)

**Non-Goals:**
- New locales (only en-US in this change)
- New screenshots or feature graphics (existing 8 screenshots remain)
- Markup in description files (plain text only)
- Mentioning premium/pricing plans

## Decisions

### Title: "CalSync - Local Calendar Sync" (28 chars)

F-Droid's 30-character limit forces a shorter subtitle than the ideal. "Local Calendar Sync" packs four keywords (local, calendar, sync) plus the app name. Alternative considered: "CalSync - Calendar Sync & Merge" (29 chars) — rejected because "merge" doesn't accurately describe copy-based sync and "local" is a stronger differentiator.

### Short description strategy

Three key differentiators: "offline", "open source", "no account". These are claims SaaS competitors structurally cannot make (their architecture requires internet, accounts, and servers). Packing them into 80 characters creates immediate contrast with competitor listings.

### Full description structure

```
1. Competitive positioning (first sentence: "free open source alternative to OneCal, CalendarBridge, Reclaim.ai")
2. What it does (2 sentences explaining the sync mechanism)
3. Differentiator bullets (privacy, offline, no account — emoji for scan-ability)
4. Feature bullets (custom names, sync preview, deletion mirroring, recurring events, Material You)
5. Use cases (who this is for)
6. Competitor call-out (re-stating the alternative positioning for SEO)
7. Privacy guarantee (no ads, no tracking, no telemetry)
```

Emojis in the feature list are deliberate — they improve scan-ability on mobile store listings and are supported by both F-Droid and Google Play.

### Competitor name-checking

Naming OneCal, CalendarBridge, and Reclaim.ai in the first sentence and last section is legal (nominative fair use) and common practice. Every one of these competitors has comparison pages naming their rivals. This captures search traffic from users looking for "OneCal alternative" or "Reclaim free alternative".

## Risks / Trade-offs

- **Competitor name-checks** → Could be perceived as negative marketing by users who prefer neutral listings. Mitigation: frame as "free and open source alternative to X" rather than "X is bad".
- **Emoji usage** → May not render on all F-Droid clients. Mitigation: emojis are decorative only; the text content is complete without them.
- **30-char F-Droid limit** → Restricts title keyword density. Mitigation: the "local" differentiator is the highest-value keyword that fits.
