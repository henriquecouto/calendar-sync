## Context

`SyncEngine._classify` is 170 lines with two distinct phases: orphan mapping cleanup and source event classification. The all-day projection logic (UTC midnight → local midnight) is duplicated in `_classify` (create path) and `_execute` (update path).

## Goals / Non-Goals

**Goals:**
- Eliminate the duplicated `_localMidnight` + `.add(Duration(days: 1))` pattern
- Improve `_classify` readability by splitting into named methods

**Non-Goals:**
- No behavior changes
- No test changes (except ensuring existing tests still pass)

## Decisions

### 1. Extract `_projectAllDayTimes(Event)` helper

Creates a `(TZDateTime, TZDateTime)` tuple from an all-day source event:

```dart
static ({TZDateTime start, TZDateTime end}) _projectAllDayTimes(Event event) {
  final start = _localMidnight(event.start!.year, event.start!.month, event.start!.day);
  return (start: start, end: start.add(const Duration(days: 1)));
}
```

Wait — multi-day events need `end = _localMidnight(event.end!.year, month, day) + 1`. The helper should handle both:

```dart
static TZDateTime _projectEnd(Event event) {
  return _localMidnight(event.end!.year, event.end!.month, event.end!.day)
      .add(const Duration(days: 1));
}
```

Both call sites: `_classify` create path and `_execute` update path.

### 2. Split `_classify` into two methods

`_classify` has two phases:
1. **Orphan handling** (lines 125-168): finds mapped source events absent from the fetch window, decides to delete or re-add
2. **Event classification** (lines 171-264): iterates source events, decides create/update/skip

Extract phase 1 into `_handleOrphanMappings(...)` — returns nothing, mutates `sourceEvents`, `toDelete`, `errors`.
