# TODOs

## Bugs

- [x] The main view is cut off somewhat. Like a letterbox? **Solution**: It was
      a compatiability issue. The `xcodegen` config was missing a field.

- [x] `AppDelegate().cancelAppRefresh()` in `stopTimer()` instantiates a new
      AppDelegate instead of using the real one. Make `cancelAppRefresh()`
      static.

- [x] The "at a glance" daily total display doesn't live-update while a timer
      is running — it only refreshes when tapped. **Root cause**: `@Observable`
      only re-renders views when tracked properties change; `dailyTotalString`
      called `Date()` directly (untracked), and when `showDailyTotal` is true
      `timerString` isn't accessed so its updates don't trigger re-renders.
      **Fix**: Added a `currentDate: Date` property updated each tick in
      `updateTimerString()`; `dailyTotalString` now reads `currentDate` instead
      of `Date()`, creating the missing dependency.

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

- [x] Break up `TimelinePickerView` — the body is ~170 lines in a single
      `GeometryReader` → `ZStack`. **Done**: Extracted `TimelineContext`
      struct and 8 private sub-view methods. Body is now a readable outline.

- [x] Replace `Timer.scheduledTimer` momentum in `TimelinePickerView` with a
      SwiftUI-native approach. **Done**: Replaced with `Task { @MainActor }`
      + `Task.sleep(for: .milliseconds(16))`. No more `DispatchQueue.main.async`.

- [x] Remove `ContentViewModel.shared` references from timeline views.
      **Done**: Replaced `SessionListItem` with an inline row in the
      bar-sessions sheet. `SessionDetailView` now receives `sessions`
      as a parameter instead of accessing the singleton. No singleton
      references remain in timeline or session detail views.

- [x] Consider unifying the three animatable position modifiers
      (`SlidingPosition`, `DateLabelSlide`, `BarPosition`). **Done**: Merged
      `DateLabelSlide` into `SlidingPosition`. `BarPosition` kept separate
      (serves a different purpose — animating row changes, not sliding).

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

- [ ] Persist active session edits to UserDefaults in real time.
      Currently `saveTimerState()` is only called from `startTimer()` and
      `stopTimer()`. If the user edits tags/title/notes mid-session and the
      app is killed, those edits are lost. Needs either: (a) call
      `saveTimerState()` on every field change (e.g. `onChange` or `didSet`),
      or (b) a periodic auto-save, or (c) move active session state into
      SwiftData so it's always persisted.

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

- [x] As a user, I want to be able to see statistics of sessions. For tagged
      sessions, I want aggregated views for day, week, and month. It should
      be possible to add the aggregate you want based on tags. For example,
      it should be possible to see statistics for a "Billable" tag.

  Details: the view should have a true black background. It should not be a
  gray pop over card. A simple table is fine to start with.

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

- [x] As a user, I want to edit a session's title, notes, tags, and start/end
      time after it's been logged. Currently SessionDetailView is read-only with
      a delete button — it should support inline editing. Edits should also sync
      to the calendar via `calendarEventID`.

---

- [ ] As a user, I want to see today's total tracked time at a glance. A small
      summary bar (e.g. "4h 23m today") above the recents section or in the
      navigation title.

---

- [ ] As a user, I want the timeline to be the primary way I browse and edit
      sessions. Scrolling should browse by default (no state changes). Tapping
      a session bar selects it and shows its details inline. Tapping Start/End
      in the details form enters scrub-editing mode where scrolling adjusts
      that timestamp. Auto-save with undo toast.

### Tasks

- [x] Phase 1+2: Browse mode, viewport decoupling, session selection, inline
      details form
- [x] Phase 3: Scrub-editing (Start/End fields activate scrub mode, visual
      indicator, constrain start < end, zoom-to-fit, undo toast)
- [x] Phase 4: Active session polish (pulse animation on active bars,
      scrub-editing start only, zoom-to-fit on active bar tap)

---

- [ ] As a user, I want more control over _tags_. Maybe I want to create
      _tag sets_ that together share some common settings. Maybe I want some
      tags to have different colors. I _do_ want to be able to aggregate
      statistics based on tags, and _tag sets_ if that is a viable construct.

---

- [x] As a user, I want a tactile feel to buttons. For example the time
      adjustment buttons.

---

- [ ] As a user, I want to set a session's start time by scrubbing a scrollable
      timeline rather than tapping +/− buttons. The timeline should have tick
      marks every 5 minutes, haptic feedback on each tick, already-logged
      sessions rendered as blocks so I can see context at a glance, and a mild
      snap to the end of the immediately preceding session. The implementation
      should be "modular", so that it can be reused (for example in the "edit"
      view). Also, I don't want to remove the old module just yet, I want to
      test out the new one first.

### Tasks

- [ ] Build `TimelinePickerView` as a self-contained SwiftUI module (no changes
      to existing start-time UI yet) — horizontal scroll view with minute
      resolution, tick marks at 5-minute intervals, current-time indicator
- [ ] Render existing sessions as shaded blocks on the timeline so the user can
      see gaps and overlaps while scrubbing
- [ ] Add `UIImpactFeedbackGenerator` (or `UISelectionFeedbackGenerator`) haptic
      pulse on each 5-minute tick crossing
- [ ] Implement snap-to-tail: when the scrubbed value comes within ~1–2 minutes
      of the end of the nearest preceding session, snap and emit a distinct
      haptic
- [ ] Wire `TimelinePickerView` into a preview/test screen so it can be
      evaluated standalone before replacing the existing start-time control

---

- [ ] As a user, I want to more easily add manual session entries. Currently
      it's only possible to add sessions by spamming start and stop, then edit
      later.

---

- [ ] As a user, I want a media-player-style bottom bar for the timer controls.

### Tasks

- [ ] Move the timer display to the very bottom of the screen (above the
      timeline), reminiscent of a media player's now-playing bar
- [ ] Move the play/stop button down to the bottom bar; add a long-press
      pop-up menu on it (e.g. quick actions)
- [ ] Change the daily total duration view so that filtering is done by
      long-pressing it and selecting tags from a pop-up menu (instead of the
      current inline tag chips)
- [ ] Show a subtle indicator (star or dot) when the daily total is filtered,
      but don't display the tag names in normal viewing
