# TODOs

## Bugs

- [ ] The main view is cut off somewhat. Like a letterbox?

- [ ] `AppDelegate().cancelAppRefresh()` in `stopTimer()` instantiates a new AppDelegate instead of using the real one. Make `cancelAppRefresh()` static.

- [ ] `onChange(of: viewModel.events) { fetchEvents() }` in ContentView is an infinite-loop risk — fires on every fetch result.

- [ ] `deleteEvent(at offsets:)` removes by index inside a loop — indices shift after each removal, corrupting multi-selection deletes.

## Code Health

- [ ] Add `@MainActor` to `ContentViewModel` — it drives UI and assumes main-thread access everywhere.

- [ ] Consolidate the three copies of `formatTime` (ContentViewModel, TimerWidgetLiveActivity, TimerWidget) into a shared utility.

- [ ] Add `@retroactive` to `EKEvent: Identifiable` conformance to silence the compiler warning and future-proof against EventKit changes.

- [ ] We might want to store data separated from the calendar. Consider it. Right now the calendar is the source of truth, the database.

## Stories

- [ ] As a user, I want to be able to see activities in a widget

  ### Tasks

  - [ ] Fix the existing widget so that it's actually in sync with current event
  - [ ] Display start button if nothing is running
  - [ ] Maybe show a subtle hint of the previous event when stopped? And be able to continue it?

- [ ] As a user, I want to merge events into each other. Would probably be nice do to in a list view: press and hold, popup, "merge into above/below", warn if overwriting name/notes or time gap is big (>15 min)?

- [ ] As a user, I want to tag events.

- [ ] As a user, I want to be able to see statistics of events. For tagged events, I want aggregated views for day, week, and month.

- [ ] As a user, I want to pause and resume a timer without logging it as a separate event. Right now stopping always writes to the calendar — a pause/resume flow would let you take breaks within one session.

- [ ] As a user, I want to start a timer directly from the Dynamic Island or Lock Screen. Currently the expanded Dynamic Island shows a stop icon but it's not interactive — adding `Button` with an `AppIntent` would make it tappable.

- [ ] As a user, I want the app to suggest event names based on what I've tracked before. The recents list is there but requires a swipe to copy — an autocomplete on the title TextField would be faster.

- [ ] As a user, I want to edit an event's start/end time after it's been logged. Currently you can only view or delete — tapping into an event could open an edit form that updates the EKEvent.

- [ ] As a user, I want to see today's total tracked time at a glance. A small summary bar (e.g. "4h 23m today") above the recents section or in the navigation title.
