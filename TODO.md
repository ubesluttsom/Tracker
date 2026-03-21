# TODOs

## Bugs

- [x] The main view is cut off somewhat. Like a letterbox? **Solution**: It was
      a compatiability issue. The `xcodegen` config was missing a field.

- [x] `AppDelegate().cancelAppRefresh()` in `stopTimer()` instantiates a new
      AppDelegate instead of using the real one. Make `cancelAppRefresh()`
      static.

- [x] `onChange(of: viewModel.events) { fetchEvents() }` in ContentView is an
      infinite-loop risk — fires on every fetch result. **Fixed**: Removed
      during SwiftData migration; `fetchSessions()` is called explicitly.

- [x] `deleteEvent(at offsets:)` removes by index inside a loop — indices shift
      after each removal, corrupting multi-selection deletes. **Fixed**:
      Rewritten as `deleteSession(at:)` during SwiftData migration.

## Code Health

- [ ] Add `@MainActor` to `ContentViewModel` — it drives UI and assumes
      main-thread access everywhere.

- [ ] Consolidate the three copies of `formatTime` (ContentViewModel,
      TimerWidgetLiveActivity, TimerWidget) into a shared utility.

- [x] Add `@retroactive` to `EKEvent: Identifiable` conformance to silence the
      compiler warning and future-proof against EventKit changes. **Fixed**:
      `EKEvent+Extensions.swift` deleted; views no longer use `EKEvent`.

- [x] We might want to store data separated from the calendar. Consider it.
      **Done**: Migrated to SwiftData as source of truth with calendar
      write-through.

- [ ] Consider dropping the `ContentViewModel` singleton in favor of SwiftUI
      environment-based injection. Currently `SessionStore` is injected manually
      from `TrackerApp.init()` because the singleton lives outside the view
      hierarchy.

## Stories

---

- [ ] As a user, I want my time-tracking sessions to stay in sync across my
      iPhone and Apple Watch, so I can log time on the go and review it
      anywhere.

### Tasks

- [x] Set up a local SwiftData store on iOS holding session data (title, notes,
      tags, etc.)
- [x] Set up an App Group shared container so the widget extension can access
      the SwiftData store
- [ ] Enable CloudKit sync on the SwiftData ModelContainer for cross-device sync
- [ ] Build watchOS target as read-only: read sessions via shared SwiftData
      store
- [ ] Handle the case where data hasn't synced yet on watch (e.g. first launch
      before iOS has synced)

---

- [ ] As a user, I want to be able to interact using my Apple Watch

### Tasks

- [ ] Skeleton
- [ ] Start / stop
- [ ] Complication
- [ ] List

---

- [ ] As a user, I want to be able to see activities in a widget

### Tasks

- [ ] Fix the existing widget so that it's actually in sync with current session
- [ ] Display start button if nothing is running
- [ ] Maybe show a subtle hint of the previous session when stopped? And be able
      to continue it?

---

- [ ] As a user, I want to merge sessions into each other. Would probably be
      nice to do in a list view: press and hold, popup, "merge into
      above/below", warn if overwriting name/notes or time gap is big (>15 min)?

---

- [x] As a user, I want to tag sessions.

---

- [ ] As a user, I want to be able to see statistics of sessions. For tagged
      sessions, I want aggregated views for day, week, and month.

---

- [ ] As a user, I want to pause and resume a timer without logging it as a
      separate session. Right now stopping always saves — a pause/resume flow
      would let you take breaks within one session.

---

- [ ] As a user, I want to start a timer directly from the Dynamic Island or
      Lock Screen. Currently the expanded Dynamic Island shows a stop icon but
      it's not interactive — adding `Button` with an `AppIntent` would make it
      tappable.

---

- [ ] As a user, I want the app to suggest session names based on what I've
      tracked before. The recents list is there but requires a swipe to copy —
      an autocomplete on the title TextField would be faster.

---

- [ ] As a user, I want to edit a session's title, notes, tags, and start/end
      time after it's been logged. Currently SessionDetailView is read-only with
      a delete button — it should support inline editing. Edits should also sync
      to the calendar via `calendarEventID`.

---

- [ ] As a user, I want to see today's total tracked time at a glance. A small
      summary bar (e.g. "4h 23m today") above the recents section or in the
      navigation title.

---

- [ ] As a user, I want more control over _tags_. Maybe I want to create
      _tag sets_ that together share some common settings. Maybe I want some
      tags to have different colors. I _do_ want to be able to aggregate
      statistics based on tags, and _tag sets_ if that is a viable construct.

---

- [x] As a user, I want a tactile feel to buttons. For example the time
      adjustment buttons.
