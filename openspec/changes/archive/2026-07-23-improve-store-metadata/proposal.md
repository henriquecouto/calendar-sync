## Why

The current Play Store and F-Droid listing metadata is flat and undiscoverable. The title is a bare "CalSync" with no keywords, the descriptions list features without competitive positioning, and there's no mention of the app's key differentiators (offline, free, open source, privacy-preserving). This is a missed opportunity: paid SaaS alternatives like OneCal ($5-25/mo), CalendarBridge ($4+/mo), and Reclaim.ai (freemium) compete for the same search terms while CalSync has a unique architectural advantage they can't match — no internet permission, no data collection, fully local operation.

## What Changes

- Rewrite `title.txt` to include keyword-rich subtitle within the 30-character limit: "CalSync - Sync & Merge Local Calendars"
- Rewrite `short_description.txt` to pack key differentiators into 80 characters: "offline", "open source", "no account"
- Rewrite `full_description.txt` to lead with competitive positioning, emphasize privacy/offline as unique selling points, add use case scenarios, and include competitor name-checks for search discoverability

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `fdroid-metadata`: Title, short description, and full description content requirements are updated to reflect the new keyword-optimized, competitively-positioned copy. The title requirement changes from "Calendar Sync" / "CalSync" to the new title. The short description drops the generic phrasing in favor of keyword-dense copy. The full description is rewritten entirely.

## Impact

- `fastlane/metadata/android/en-US/title.txt` — new content
- `fastlane/metadata/android/en-US/short_description.txt` — new content
- `fastlane/metadata/android/en-US/full_description.txt` — rewritten
- `openspec/specs/fdroid-metadata/spec.md` — updated requirements for title and description content
