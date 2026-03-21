# TODOs

## Bugs

- [x] The main view is cut off somewhat. Like a letterbox? **Solution**: It was
      a compatiability issue. The `xcodegen` config was missing a field.

- [x] `AppDelegate().cancelAppRefresh()` in `stopTimer()` instantiates a new
      AppDelegate instead of using the real one. Make `cancelAppRefresh()`
      static.

- [ ] `onChange(of: viewModel.events) { fetchEvents() }` in ContentView is an
      infinite-loop risk — fires on every fetch result.

- [ ] `deleteEvent(at offsets:)` removes by index inside a loop — indices shift
      after each removal, corrupting multi-selection deletes.

## Code Health

- [ ] Add `@MainActor` to `ContentViewModel` — it drives UI and assumes
      main-thread access everywhere.

- [ ] Consolidate the three copies of `formatTime` (ContentViewModel,
      TimerWidgetLiveActivity, TimerWidget) into a shared utility.

- [ ] Add `@retroactive` to `EKEvent: Identifiable` conformance to silence the
      compiler warning and future-proof against EventKit changes.

- [ ] We might want to store data separated from the calendar. Consider it.
      Right now the calendar is the source of truth, the database.

## Stories

---

- [ ] As a user, I want my time-tracking events to stay in sync across my iPhone
      and Apple Watch, with custom metadata (project, tags, billable) preserved,
      so I can log time on the go and review it anywhere.

### Tasks

- [ ] On event creation, generate a stable UUID and embed it in the event's
      `notes` field using a parseable format (e.g. `[[tracker-id:UUID]]`)
- [ ] On event read, parse the `notes` field to extract the stable ID and strip
      it from any user-visible notes
- [ ] Set up a local SQLite (or equivalent) store on iOS, keyed on stable UUID,
      holding custom metadata (project, tags, billable, etc.)
- [ ] Set up CloudKit (or iCloud KV) to sync the metadata store across devices
- [ ] Set up an App Group shared container so the iOS and watchOS targets can
      both access the metadata store
- [ ] Build watchOS target as read-only: read events via EventKit, look up
      metadata via shared container
- [ ] Handle the case where metadata doesn't exist yet for a given UUID (e.g.
      first launch on watch before iOS has synced)
- [ ] Test CalDAV round-trip: create event on device, let it sync, verify stable
      UUID survives in `notes`

---

- [ ] As a user, I want to be able to be able to interact using my Apple Watch

## Tasks

- [ ] Skeleton
- [ ] Start / stop
- [ ] Complication
- [ ] List

---

- [ ] As a user, I want to be able to see activities in a widget

### Tasks

- [ ] Fix the existing widget so that it's actually in sync with current event
- [ ] Display start button if nothing is running
- [ ] Maybe show a subtle hint of the previous event when stopped? And be able
      to continue it?

---

- [ ] As a user, I want to merge events into each other. Would probably be nice
      do to in a list view: press and hold, popup, "merge into above/below",
      warn if overwriting name/notes or time gap is big (>15 min)?

---

- [ ] As a user, I want to tag events.

---

- [ ] As a user, I want to be able to see statistics of events. For tagged
      events, I want aggregated views for day, week, and month.

---

- [ ] As a user, I want to pause and resume a timer without logging it as a
      separate event. Right now stopping always writes to the calendar — a
      pause/resume flow would let you take breaks within one session.

---

- [ ] As a user, I want to start a timer directly from the Dynamic Island or
      Lock Screen. Currently the expanded Dynamic Island shows a stop icon but
      it's not interactive — adding `Button` with an `AppIntent` would make it
      tappable.

---

- [ ] As a user, I want the app to suggest event names based on what I've
      tracked before. The recents list is there but requires a swipe to copy —
      an autocomplete on the title TextField would be faster.

---

- [ ] As a user, I want to edit an event's start/end time after it's been
      logged. Currently you can only view or delete — tapping into an event
      could open an edit form that updates the EKEvent.

---

- [ ] As a user, I want to see today's total tracked time at a glance. A small
      summary bar (e.g. "4h 23m today") above the recents section or in the
      navigation title.
