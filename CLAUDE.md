# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Regenerate Xcode project from project.yml (required after adding/removing files)
xcodegen generate

# Build both targets (main app + widget extension)
xcodebuild -project Tracker.xcodeproj -scheme Tracker -destination 'platform=iOS Simulator,name=iPhone 16' build

# Quiet build (errors/warnings only)
xcodebuild -project Tracker.xcodeproj -scheme Tracker -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build
```

No test targets are active. No linter is configured.

## Architecture

Tracker is a time-tracking iOS app that logs timer sessions as calendar events via EventKit. It has two targets defined in `project.yml`:

- **Tracker** — main SwiftUI app (iOS 17.5+)
- **TimerWidgetExtension** — WidgetKit extension for Live Activities (Dynamic Island / Lock Screen) and a home-screen widget

### Data flow

`ContentViewModel` is a singleton (`ContentViewModel.shared`) using iOS 17's `@Observable`. All views share this instance. Timer state is persisted to UserDefaults so it survives app termination; on relaunch `loadTimerState()` restores it. When a timer stops, the session is written to a dedicated "Tracker" calendar via `CalendarHelper`.

Views that need `$`-bindings to the view model use `@Bindable`; views that only read use a plain `var`.

### Shared code between targets

`TimerWidgetAttributes` (in `Tracker/Core/Models/`) is compiled into **both** targets — the main app needs it to start/update Live Activities, and the widget extension needs it to render them. This is configured in `project.yml` as an explicit additional source for `TimerWidgetExtension`.

### Background updates

`AppDelegate` registers a `BGAppRefreshTask` (`no.mihle.Tracker.refresh`) that wakes the app every ~60s while backgrounded to push Live Activity updates. The identifier must match `BGTaskSchedulerPermittedIdentifiers` in `Tracker/Info.plist`.

### Key conventions

- Zero external dependencies — only system frameworks (EventKit, WidgetKit, ActivityKit, BackgroundTasks, AppIntents).
- XcodeGen manages the `.xcodeproj` — never edit it by hand. The `.xcodeproj/` is gitignored; `project.yml` is the source of truth.
- `CalendarHelper` uses a single static `EKEventStore` to avoid EventKit merge conflicts.
