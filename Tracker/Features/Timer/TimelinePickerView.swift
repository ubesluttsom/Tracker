import SwiftData
import SwiftUI

struct TimelinePickerView: View {
  @Binding var selectedTime: Date
  var sessions: [Session]
  var visibleHours: Double = 4.0
  var activeTags: [String] = []
  var activeSessionStart: Date?
  @Binding var isInteracting: Bool
  var highlightedSessionIDs: Set<UUID> = []
  var isScrubbing: Bool = false
  var alwaysExpanded: Bool = false
  var onBarTap: ((TagBar) -> Void)?

  // --- Drag state ---
  @State private var dragAnchor: Date?
  @State private var isDraggingTimeline: Bool?

  // --- Momentum state ---
  @State private var velocity: Double = 0
  @State private var momentumTask: Task<Void, Never>?

  // --- Haptic state ---
  @State private var tickHapticTrigger: Int = 0
  @State private var snapHapticTrigger: Int = 0
  @State private var lastTickSlot: Int = 0
  @State private var isSnapped: Bool = false

  // --- Expansion ---
  @State private var isExpanded: Bool = false
  @State private var collapseTask: Task<Void, Never>?

  // --- Pickers ---
  @State private var showDatePicker: Bool = false
  @State private var showTimePicker: Bool = false

  // ┌──────────────────────────────────────────────────┐
  // │  TWEAKABLE CONSTANTS — start here when tuning    │
  // └──────────────────────────────────────────────────┘
  private let frictionFactor: Double = 0.94
  private let velocityStopThreshold: Double = 30.0
  private let flingMinVelocity: Double = 150.0

  private let hourTickHeight: CGFloat = 8
  private let hourTickWidth: CGFloat = 1.5
  private let quarterTickHeight: CGFloat = 4
  private let quarterTickWidth: CGFloat = 1.5
  private let fiveMinDotRadius: CGFloat = 1.0

  private let snapThreshold: TimeInterval = 120
  private let unSnapThreshold: TimeInterval = 150

  private let hapticTickMinutes: Int = 5

  private let tickAreaHeight: CGFloat = 34

  private var effectiveExpanded: Bool { alwaysExpanded || isExpanded }

  private var totalHeight: CGFloat {
    let maxTags = TagTimelineBarsView.maxTagCount(
      sessions: sessions, activeTags: activeTags,
      hasActiveSession: activeSessionStart != nil
    )
    return tickAreaHeight + TagTimelineBarsView.barAreaHeight(maxTagCount: maxTags, isExpanded: effectiveExpanded)
  }

  // A label snaps to center when it's the closest AND within
  // this distance (points). Binary: either captured or not.
  private let captureRadius: CGFloat = 60

  // MARK: - Body

  var body: some View {
    GeometryReader { geo in
      let ctx = TimelineContext(
        selectedTime: selectedTime,
        visibleHours: visibleHours,
        width: geo.size.width,
        tickAreaHeight: tickAreaHeight,
        hourTickHeight: hourTickHeight,
        activeSessionStart: activeSessionStart
      )

      ZStack {
        tickCanvas(ctx)
        tagBars(ctx)
        accentTickOverlay(ctx)
        scrubIndicator(ctx)
        hourLabels(ctx)
        centerTapTarget(ctx)
        dateLabel(ctx)
      }
      .frame(width: ctx.width, height: totalHeight)
      .contentShape(Rectangle())
      .simultaneousGesture(timelineDragGesture(pps: ctx.pps))
      .sensoryFeedback(.selection, trigger: tickHapticTrigger)
      .sensoryFeedback(.impact(weight: .heavy), trigger: snapHapticTrigger)
      .onTapGesture {
        expandBars()
        scheduleCollapse()
      }
    }
    .frame(height: totalHeight)
    .animation(.spring(duration: 0.4, bounce: 0.12), value: effectiveExpanded)
    .onAppear { initSlot() }
    .onDisappear { stopMomentum(); collapseTask?.cancel() }
    .sheet(isPresented: $showDatePicker) { datePickerSheet }
    .sheet(isPresented: $showTimePicker) { timePickerSheet }
  }

  // MARK: - Sub-views

  private func tickCanvas(_ ctx: TimelineContext) -> some View {
    Canvas { context, size in
      drawTicks(context: &context, size: size,
                windowStart: ctx.windowStart, pps: ctx.pps,
                skipTick: ctx.accentSnappedTick)
    }
    .frame(width: ctx.width, height: totalHeight)
  }

  private func tagBars(_ ctx: TimelineContext) -> some View {
    // TimelineView forces a re-render every 60 s so the active bar's
    // right edge (endDate: now) grows in real time without scrubbing.
    TimelineView(.periodic(from: .now, by: 60)) { tlContext in
      TagTimelineBarsView(
        sessions: sessions,
        activeTags: activeTags,
        activeSessionStart: activeSessionStart,
        windowStart: ctx.windowStart,
        windowEnd: ctx.windowEnd,
        pps: ctx.pps,
        baseline: tickAreaHeight,
        now: tlContext.date,
        isExpanded: effectiveExpanded,
        visibleWidth: ctx.width,
        highlightedSessionIDs: highlightedSessionIDs,
        onBarTap: { bar in onBarTap?(bar) }
      )
    }
    .frame(width: ctx.width, height: totalHeight)
    .allowsHitTesting(effectiveExpanded)
  }

  @ViewBuilder
  private func accentTickOverlay(_ ctx: TimelineContext) -> some View {
    if activeSessionStart != nil {
      let centerSecs = selectedTime.timeIntervalSinceReferenceDate
      let snapped300 = (centerSecs / 300).rounded() * 300
      let accentCandidates = (-1...1).map {
        Date(timeIntervalSinceReferenceDate: snapped300 + Double($0) * 300)
      }
      let closestTick = accentCandidates.min(by: {
        abs($0.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX) <
        abs($1.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX)
      })!
      let closestTickDist = abs(closestTick.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX)
      let shouldCaptureTick = closestTickDist < ctx.pps * 150

      ForEach(accentCandidates, id: \.self) { tick in
        let nx = tick.timeIntervalSince(ctx.windowStart) * ctx.pps
        let captured = shouldCaptureTick && tick == closestTick
        let minute = Calendar.current.component(.minute, from: tick)
        let tickCenterY: CGFloat = {
          if minute == 0 { return ctx.baseline - hourTickHeight / 2 }
          else if minute % 15 == 0 { return ctx.baseline - quarterTickHeight / 2 }
          else { return ctx.baseline - fiveMinDotRadius }
        }()

        AccentTickShape(minute: minute, isCaptured: captured)
          .opacity(captured ? 1 : 0)
          .modifier(SlidingPosition(
            progress: captured ? 1 : 0,
            fromX: nx,
            toX: ctx.centerX,
            y: tickCenterY
          ))
          .animation(.spring(duration: 0.18, bounce: 0.15), value: captured)
      }
    }
  }

  @ViewBuilder
  private func scrubIndicator(_ ctx: TimelineContext) -> some View {
    if isScrubbing {
      // Vertical line at the center showing the scrub position
      RoundedRectangle(cornerRadius: 1)
        .fill(Color.accentColor.opacity(0.6))
        .frame(width: 2, height: totalHeight - ctx.labelY)
        .position(x: ctx.centerX, y: ctx.labelY + (totalHeight - ctx.labelY) / 2)

      // Small diamond handle at top
      Image(systemName: "diamond.fill")
        .font(.system(size: 8))
        .foregroundStyle(.blue)
        .position(x: ctx.centerX, y: ctx.labelY + 4)
    }
  }

  @ViewBuilder
  private func hourLabels(_ ctx: TimelineContext) -> some View {
    let hours = visibleHourDates(in: ctx.windowStart, end: ctx.windowEnd)
    let closestHour: Date? = isInteracting ? hours.min(by: {
      abs($0.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX) <
      abs($1.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX)
    }) : nil
    let closestDist: Double = closestHour.map {
      abs($0.timeIntervalSince(ctx.windowStart) * ctx.pps - ctx.centerX)
    } ?? Double.greatestFiniteMagnitude
    let shouldCapture = closestDist < captureRadius

    ForEach(hours, id: \.self) { hourDate in
      let naturalX = hourDate.timeIntervalSince(ctx.windowStart) * ctx.pps
      let isCaptured = shouldCapture && closestHour == hourDate
      let hour = Calendar.current.component(.hour, from: hourDate)
      let labelOpacity: Double = {
        guard !(ctx.midnightInView && hour == 0) else { return 0 }
        let dist = abs(naturalX - ctx.dateLabelX)
        let threshold: CGFloat = 80
        guard dist < threshold else { return 1.0 }
        let t = dist / threshold
        return Double(t * t * (3 - 2 * t))
      }()

      Group {
        if isCaptured {
          Text(selectedTime.formatted(.dateTime.hour().minute()))
            .font(.caption2.monospacedDigit().bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.thinMaterial))
        } else {
          Text(String(format: "%02d", hour))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .opacity(labelOpacity)
      .blur(radius: (1.0 - labelOpacity) * 3)
      .modifier(SlidingPosition(
        progress: isCaptured ? 1 : 0,
        fromX: naturalX,
        toX: ctx.centerX,
        y: ctx.labelY
      ))
      .animation(.spring(duration: 0.18, bounce: 0.15), value: isCaptured)
    }
  }

  private func centerTapTarget(_ ctx: TimelineContext) -> some View {
    Color.clear
      .frame(width: 80, height: 44)
      .contentShape(Rectangle())
      .onTapGesture { showTimePicker = true }
      .position(x: ctx.centerX, y: ctx.labelY)
  }

  @ViewBuilder
  private func dateLabel(_ ctx: TimelineContext) -> some View {
    let dateToDisplay = ctx.midnightInView ? ctx.midnightDate : selectedTime
    Button { showDatePicker = true } label: {
      Text(dateToDisplay.formatted(.dateTime.month(.abbreviated).day()))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .modifier(SlidingPosition(
      progress: ctx.midnightInView ? 1 : 0,
      fromX: 30,
      toX: ctx.midnightX,
      y: ctx.labelY
    ))
    .animation(.spring(duration: 0.18, bounce: 0.15), value: ctx.midnightInView)
  }

  // MARK: - Sheet Content

  private var datePickerSheet: some View {
    DatePicker("", selection: $selectedTime, in: .distantPast...Date(), displayedComponents: .date)
      .labelsHidden()
      .datePickerStyle(.graphical)
      .padding()
      .presentationDetents([.medium])
  }

  private var timePickerSheet: some View {
    let cal = Calendar.current
    return VStack(spacing: 0) {
      TimeAdjustmentButtons(selectedTime: $selectedTime)
        .padding(.horizontal)
        .padding(.top, 12)

      HStack(spacing: 0) {
        Picker("", selection: Binding(
          get: { cal.component(.hour, from: selectedTime) },
          set: { h in
            var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
            c.hour = h
            if let d = cal.date(from: c) { selectedTime = min(d, Date()) }
          }
        )) {
          ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)

        Picker("", selection: Binding(
          get: { cal.component(.minute, from: selectedTime) },
          set: { m in
            var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
            c.minute = m
            if let d = cal.date(from: c) { selectedTime = min(d, Date()) }
          }
        )) {
          ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
      }
    }
    .presentationDetents([.height(280)])
    .presentationDragIndicator(.visible)
  }

  // MARK: - Gesture

  private func timelineDragGesture(pps: Double) -> some Gesture {
    DragGesture(minimumDistance: 4)
      .onChanged { value in
        if isDraggingTimeline == nil {
          isDraggingTimeline = abs(value.translation.width) >= abs(value.translation.height)
          if isDraggingTimeline == true {
            dragAnchor = selectedTime
            stopMomentum()
            isInteracting = true
            expandBars()
          }
        }
        guard isDraggingTimeline == true, let anchor = dragAnchor else { return }

        let secondsDelta = -value.translation.width / pps
        let candidate = anchor.addingTimeInterval(secondsDelta)
        let clamped = min(candidate, Date())
        let rounded = clamped.nearestMinute()

        let snapped = snapToSessionEnd(
          candidate: rounded,
          threshold: isSnapped ? unSnapThreshold : snapThreshold
        )
        if snapped.didSnap {
          if !isSnapped { isSnapped = true; snapHapticTrigger += 1 }
          selectedTime = snapped.time
        } else {
          isSnapped = false
          selectedTime = rounded
        }

        updateTickHaptic()
      }
      .onEnded { value in
        let pointsPerSec = value.predictedEndTranslation.width - value.translation.width
        let velocityCandidate = -pointsPerSec / pps

        if abs(velocityCandidate) > flingMinVelocity {
          velocity = velocityCandidate
          startMomentum()
        } else {
          isInteracting = false
          scheduleCollapse()
        }

        isDraggingTimeline = nil
        dragAnchor = nil
        isSnapped = false
      }
  }

  // MARK: - Visible Hours

  private func visibleHourDates(in start: Date, end: Date) -> [Date] {
    let calendar = Calendar.current
    let comps = calendar.dateComponents([.year, .month, .day, .hour], from: start)
    guard let firstHour = calendar.date(from: comps) else { return [] }
    var cursor = firstHour < start ? firstHour.addingTimeInterval(3600) : firstHour
    var hours: [Date] = []
    while cursor <= end {
      hours.append(cursor)
      cursor = cursor.addingTimeInterval(3600)
    }
    return hours
  }

  // MARK: - Bar Expansion

  private func expandBars() {
    guard !alwaysExpanded else { return }
    collapseTask?.cancel()
    isExpanded = true
  }

  private func scheduleCollapse() {
    guard !alwaysExpanded else { return }
    collapseTask?.cancel()
    collapseTask = Task {
      try? await Task.sleep(for: .seconds(2.5))
      guard !Task.isCancelled else { return }
      await MainActor.run {
        isExpanded = false
      }
    }
  }

  // MARK: - Momentum

  private func startMomentum() {
    momentumTask?.cancel()
    momentumTask = Task { @MainActor in
      while !Task.isCancelled {
        velocity *= frictionFactor
        if abs(velocity) < velocityStopThreshold {
          isInteracting = false
          scheduleCollapse()
          break
        }
        let newTime = selectedTime.addingTimeInterval(velocity / 60).nearestMinute()
        let clamped = min(newTime, Date().nearestMinute())
        if clamped != selectedTime { selectedTime = clamped }
        if clamped >= Date().nearestMinute() {
          isInteracting = false
          scheduleCollapse()
          break
        }
        try? await Task.sleep(for: .milliseconds(16))
      }
      velocity = 0
    }
  }

  private func stopMomentum() {
    momentumTask?.cancel()
    momentumTask = nil
    velocity = 0
  }

  // MARK: - Haptic Helpers

  private func updateTickHaptic() {
    let calendar = Calendar.current
    let totalMinutes = calendar.component(.hour, from: selectedTime) * 60
      + calendar.component(.minute, from: selectedTime)
    let currentSlot = totalMinutes / hapticTickMinutes
    if currentSlot != lastTickSlot {
      lastTickSlot = currentSlot
      tickHapticTrigger += 1
    }
  }

  private func initSlot() {
    let calendar = Calendar.current
    let totalMinutes = calendar.component(.hour, from: selectedTime) * 60
      + calendar.component(.minute, from: selectedTime)
    lastTickSlot = totalMinutes / hapticTickMinutes
  }

  // MARK: - Drawing (Canvas)

  private func drawTicks(
    context: inout GraphicsContext, size: CGSize,
    windowStart: Date, pps: Double,
    skipTick: Date? = nil
  ) {
    let calendar = Calendar.current
    let totalMinutes = Int(visibleHours * 60)
    let startMinute = calendar.dateInterval(of: .minute, for: windowStart)?.start ?? windowStart
    let baseline = tickAreaHeight

    for i in 0...totalMinutes {
      let tickDate = startMinute.addingTimeInterval(Double(i) * 60)
      let minute = calendar.component(.minute, from: tickDate)
      guard minute % 5 == 0 else { continue }
      if let skip = skipTick, abs(skip.timeIntervalSince(tickDate)) < 1 { continue }
      let x = tickDate.timeIntervalSince(windowStart) * pps

      if minute == 0 {
        let rect = CGRect(
          x: x - hourTickWidth / 2,
          y: baseline - hourTickHeight,
          width: hourTickWidth,
          height: hourTickHeight
        )
        context.fill(
          Path(roundedRect: rect, cornerRadius: hourTickWidth / 2),
          with: .color(.primary.opacity(0.55))
        )
      } else if minute % 15 == 0 {
        let rect = CGRect(
          x: x - quarterTickWidth / 2,
          y: baseline - quarterTickHeight,
          width: quarterTickWidth,
          height: quarterTickHeight
        )
        context.fill(
          Path(roundedRect: rect, cornerRadius: quarterTickWidth / 2),
          with: .color(.primary.opacity(0.4))
        )
      } else {
        let r = fiveMinDotRadius
        let dotRect = CGRect(x: x - r, y: baseline - r * 2, width: r * 2, height: r * 2)
        context.fill(
          Path(ellipseIn: dotRect),
          with: .color(.primary.opacity(0.3))
        )
      }
    }
  }

  // MARK: - Snap Logic

  private func snapToSessionEnd(
    candidate: Date, threshold: TimeInterval
  ) -> (time: Date, didSnap: Bool) {
    var bestEnd: Date?
    var bestGap: TimeInterval = .greatestFiniteMagnitude
    for session in sessions {
      let gap = abs(candidate.timeIntervalSince(session.endDate))
      if gap < bestGap { bestGap = gap; bestEnd = session.endDate }
    }
    if let target = bestEnd, bestGap <= threshold {
      return (target, true)
    }
    return (candidate, false)
  }
}

// MARK: - Timeline Context

/// Bundles the computed values derived from `GeometryReader` and
/// `selectedTime` that most sub-views need.
private struct TimelineContext {
  let width: CGFloat
  let pps: Double
  let windowStart: Date
  let windowEnd: Date
  let centerX: CGFloat
  let baseline: CGFloat
  let labelY: CGFloat

  // Midnight
  let midnightDate: Date
  let midnightInView: Bool
  let midnightX: CGFloat
  let dateLabelX: CGFloat

  // Accent tick
  let accentSnappedTick: Date?

  init(
    selectedTime: Date,
    visibleHours: Double,
    width: CGFloat,
    tickAreaHeight: CGFloat,
    hourTickHeight: CGFloat,
    activeSessionStart: Date?
  ) {
    self.width = width
    self.pps = width / (visibleHours * 3600)
    self.windowStart = selectedTime.addingTimeInterval(-visibleHours * 3600 / 2)
    self.windowEnd = selectedTime.addingTimeInterval(visibleHours * 3600 / 2)
    self.centerX = width / 2
    self.baseline = tickAreaHeight
    self.labelY = tickAreaHeight - hourTickHeight - 12

    // Midnight
    let cal = Calendar.current
    var d = cal.startOfDay(for: windowStart)
    if d <= windowStart { d = cal.date(byAdding: .day, value: 1, to: d)! }
    self.midnightDate = d
    self.midnightInView = d <= windowEnd
    self.midnightX = d.timeIntervalSince(windowStart) * pps
    self.dateLabelX = midnightInView ? midnightX : 30

    // Accent tick
    self.accentSnappedTick = activeSessionStart.map { _ in
      let secs = selectedTime.timeIntervalSinceReferenceDate
      return Date(timeIntervalSinceReferenceDate: (secs / 300).rounded() * 300)
    }
  }
}

// MARK: - Sliding Position (Animatable)

/// A modifier that slides a view between two X positions.
/// Only `progress` is in `animatableData`, so SwiftUI interpolates it
/// without touching `fromX`/`toX` — those track dragging instantly.
private struct SlidingPosition: ViewModifier, Animatable {
  var progress: CGFloat   // 0 = at fromX, 1 = at toX
  var fromX: CGFloat      // natural position (changes every frame)
  var toX: CGFloat        // target position (e.g. center or midnight)
  var y: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    content.position(
      x: fromX + (toX - fromX) * progress,
      y: y
    )
  }
}

// MARK: - Accent Tick

private struct AccentTickShape: View {
  let minute: Int
  let isCaptured: Bool

  var body: some View {
    if minute == 0 {
      RoundedRectangle(cornerRadius: 0.75)
        .fill(Color.accentColor.opacity(0.8))
        .frame(width: isCaptured ? 2 : 1.5, height: isCaptured ? 10 : 8)
    } else if minute % 15 == 0 {
      RoundedRectangle(cornerRadius: 0.75)
        .fill(Color.accentColor.opacity(0.8))
        .frame(width: isCaptured ? 2 : 1.5, height: isCaptured ? 6 : 4)
    } else {
      Circle()
        .fill(Color.accentColor.opacity(0.8))
        .frame(width: isCaptured ? 3 : 2, height: isCaptured ? 3 : 2)
    }
  }
}

// MARK: - Helpers

private extension Date {
  func nearestMinute() -> Date {
    Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / 60).rounded() * 60)
  }
}
