import SwiftUI

// MARK: - Edit Target

/// What the Details form is currently editing.
enum EditTarget: Equatable {
  case active
  case saved(Session)

  static func == (lhs: EditTarget, rhs: EditTarget) -> Bool {
    switch (lhs, rhs) {
    case (.active, .active): return true
    case (.saved(let a), .saved(let b)): return a.id == b.id
    default: return false
    }
  }
}

// MARK: - Timer Form View

struct TimerFormView: View {
  @Bindable var viewModel: ContentViewModel
  @State private var timelineInteracting = false
  @State private var viewportCenter: Date = Date()
  @State private var editTarget: EditTarget? = nil

  // Editing state for saved sessions
  @State private var editTitle: String = ""
  @State private var editNotes: String = ""
  @State private var editTags: [String] = []
  @State private var editStartDate: Date = Date()
  @State private var editEndDate: Date = Date()

  // Scrub-editing
  enum ScrubField { case start, end }
  @State private var scrubField: ScrubField? = nil

  // Zoom-to-fit
  @State private var visibleHours: Double = 4.0

  // Undo
  @State private var undoSnapshot: (start: Date, end: Date)? = nil
  @State private var showUndoToast: Bool = false
  @State private var undoSession: Session? = nil
  @State private var undoDismissTask: Task<Void, Never>? = nil

  // Multi-session bar picker
  @State private var barTapSessions: [Session] = []
  @State private var showBarSessions: Bool = false

  private var highlightedSessionIDs: Set<UUID> {
    switch editTarget {
    case .saved(let session): return [session.id]
    case .active:
      // For the active session, we don't have a persisted ID —
      // the highlight is handled by the active bar styling
      return []
    case nil: return []
    }
  }

  /// The binding passed to the timeline — changes target based on scrub mode.
  private var timelineBinding: Binding<Date> {
    switch (editTarget, scrubField) {
    case (.active, .start):
      // Scrubbing the active session's start time
      return Binding(
        get: { viewModel.startTime ?? Date() },
        set: { viewModel.startTime = $0 }
      )
    case (.saved, .start):
      return $editStartDate
    case (.saved, .end):
      return $editEndDate
    default:
      return $viewportCenter
    }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(spacing: 0) {
        TimelinePickerView(
          selectedTime: timelineBinding,
          sessions: viewModel.todaySessions,
          visibleHours: visibleHours,
          activeTags: viewModel.sessionTags,
          activeSessionStart: viewModel.timerRunning ? viewModel.startTime : nil,
          isInteracting: $timelineInteracting,
          highlightedSessionIDs: highlightedSessionIDs,
          isScrubbing: scrubField != nil,
          alwaysExpanded: viewModel.timerRunning,
          onBarTap: { bar in handleBarTap(bar) }
        )
        .modifier(TimelineEdgeFade())
        .padding(.vertical, 4)

        List {
          detailsSection

          if editTarget == nil {
            Section(header: Text("Recents")) {
              SessionRecentsView(viewModel: viewModel)
            }
          }
        }
        .refreshable {
          viewModel.fetchSessions()
        }
        .scrollDisabled(timelineInteracting)
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: $showBarSessions) { barSessionsSheet }
      }

      // Undo toast
      if showUndoToast {
        undoToast
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .padding(.bottom, 16)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: showUndoToast)
    .onChange(of: editStartDate) { _, newValue in
      if scrubField == .start && newValue >= editEndDate {
        editStartDate = editEndDate.addingTimeInterval(-60)
      }
      // Live update: write through to session
      if scrubField == .start, case .saved(let session) = editTarget {
        session.startDate = newValue
      }
    }
    .onChange(of: editEndDate) { _, newValue in
      if scrubField == .end && newValue <= editStartDate {
        editEndDate = editStartDate.addingTimeInterval(60)
      }
      if scrubField == .end && newValue > Date() {
        editEndDate = Date()
      }
      // Live update: write through to session
      if scrubField == .end, case .saved(let session) = editTarget {
        session.endDate = newValue
      }
    }
  }

  // MARK: - Details Section

  @ViewBuilder
  private var detailsSection: some View {
    switch editTarget {
    case nil:
      Section(header: Text("Details")) {
        TextField("Title", text: $viewModel.sessionName)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TextField("Notes", text: $viewModel.sessionNotes)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TagInputView(tags: $viewModel.sessionTags)
      }

    case .active:
      // Active session selected — show details + scrub-editable start
      Section(header: HStack {
        Text("Active Session")
        Spacer()
        Button("Done") {
          withAnimation {
            editTarget = nil
            scrubField = nil
          }
          resetVisibleHours()
        }
        .font(.subheadline)
      }) {
        TextField("Title", text: $viewModel.sessionName)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TextField("Notes", text: $viewModel.sessionNotes)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TagInputView(tags: $viewModel.sessionTags)
      }

      if let startTime = viewModel.startTime {
        Section(header: Text("Time")) {
          Button {
            if scrubField == .start {
              withAnimation { scrubField = nil }
            } else {
              withAnimation { scrubField = .start }
            }
          } label: {
            HStack {
              Text("Start")
                .foregroundStyle(.primary)
              Spacer()
              Text(startTime.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(scrubField == .start ? .blue : .secondary)
            }
          }
          .listRowBackground(scrubField == .start ? Color.blue.opacity(0.08) : nil)

          LabeledContent("Running") {
            Text(formatDuration(Date().timeIntervalSince(startTime)))
              .foregroundStyle(.secondary)
          }
        }
      }

    case .saved(let session):
      // Editing a saved session inline
      Section(header: HStack {
        Text("Editing Session")
        Spacer()
        Button("Done") {
          finishEditing(session)
        }
        .font(.subheadline)
      }) {
        TextField("Title", text: $editTitle)
          .padding(.vertical, 4)
        TextField("Notes", text: $editNotes)
          .padding(.vertical, 4)
        TagInputView(tags: $editTags)
      }

      Section(header: Text("Time")) {
        // Start — tappable to enter scrub mode
        Button {
          toggleScrub(.start)
        } label: {
          HStack {
            Text("Start")
              .foregroundStyle(.primary)
            Spacer()
            Text(editStartDate.formatted(date: .omitted, time: .shortened))
              .foregroundStyle(scrubField == .start ? .blue : .secondary)
          }
        }
        .listRowBackground(scrubField == .start ? Color.blue.opacity(0.08) : nil)

        // End — tappable to enter scrub mode
        Button {
          toggleScrub(.end)
        } label: {
          HStack {
            Text("End")
              .foregroundStyle(.primary)
            Spacer()
            Text(editEndDate.formatted(date: .omitted, time: .shortened))
              .foregroundStyle(scrubField == .end ? .blue : .secondary)
          }
        }
        .listRowBackground(scrubField == .end ? Color.blue.opacity(0.08) : nil)

        LabeledContent("Duration") {
          Text(formatDuration(editEndDate.timeIntervalSince(editStartDate)))
            .foregroundStyle(.secondary)
        }
      }

      if scrubField != nil {
        Section {
          HStack {
            Text("Scrubbing \(scrubField == .start ? "start" : "end") time — drag the timeline")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Done") {
              withAnimation { scrubField = nil }
              zoomToFit(session: nil, start: editStartDate, end: editEndDate)
            }
            .font(.caption.bold())
          }
        }
      }

      Section {
        Button("Delete Session", role: .destructive) {
          viewModel.deleteSession(session)
          withAnimation {
            editTarget = nil
            scrubField = nil
          }
          resetVisibleHours()
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: - Bar Tap Handling

  private func handleBarTap(_ bar: TagBar) {
    if bar.isActive {
      withAnimation { editTarget = .active }
      if let start = viewModel.startTime {
        zoomToFit(session: nil, start: start, end: Date())
      }
      return
    }

    let matching = viewModel.sessions.filter { bar.sessionIDs.contains($0.id) }
    guard !matching.isEmpty else { return }

    if matching.count == 1 {
      selectSession(matching[0])
    } else {
      barTapSessions = matching
      showBarSessions = true
    }
  }

  private func selectSession(_ session: Session) {
    editTitle = session.title
    editNotes = session.notes
    editTags = session.tags
    editStartDate = session.startDate
    editEndDate = session.endDate
    undoSnapshot = (start: session.startDate, end: session.endDate)
    withAnimation { editTarget = .saved(session) }
    zoomToFit(session: session, start: session.startDate, end: session.endDate)
  }

  private func finishEditing(_ session: Session) {
    let timesChanged = session.startDate != editStartDate || session.endDate != editEndDate
    saveEditsToSession(session)
    withAnimation {
      editTarget = nil
      scrubField = nil
    }
    resetVisibleHours()

    if timesChanged, let snapshot = undoSnapshot {
      undoSession = session
      showUndoToast = true
      undoSnapshot = snapshot
      undoDismissTask?.cancel()
      undoDismissTask = Task {
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled else { return }
        await MainActor.run {
          withAnimation { showUndoToast = false }
          undoSnapshot = nil
          undoSession = nil
        }
      }
    }
  }

  private func saveEditsToSession(_ session: Session) {
    session.title = editTitle.trimmingCharacters(in: .whitespaces)
    session.notes = editNotes
    session.tags = editTags
    session.startDate = editStartDate
    session.endDate = editEndDate
    viewModel.updateSession(session)
  }

  // MARK: - Scrub Editing

  private func toggleScrub(_ field: ScrubField) {
    if scrubField == field {
      withAnimation { scrubField = nil }
      if case .saved = editTarget {
        zoomToFit(session: nil, start: editStartDate, end: editEndDate)
      }
    } else {
      withAnimation { scrubField = field }
    }
  }

  // MARK: - Zoom

  private func zoomToFit(session: Session?, start: Date, end: Date) {
    let duration = end.timeIntervalSince(start)
    let paddedHours = max((duration / 3600) * 1.6, 1.0)
    let center = start.addingTimeInterval(duration / 2)
    withAnimation(.easeInOut(duration: 0.4)) {
      visibleHours = paddedHours
      viewportCenter = center
    }
  }

  private func resetVisibleHours() {
    withAnimation(.easeInOut(duration: 0.4)) {
      visibleHours = 4.0
    }
  }

  private func formatDuration(_ interval: TimeInterval) -> String {
    let total = Int(max(interval, 0))
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
  }

  // MARK: - Undo

  private func performUndo() {
    guard let session = undoSession, let snapshot = undoSnapshot else { return }
    session.startDate = snapshot.start
    session.endDate = snapshot.end
    viewModel.updateSession(session)
    withAnimation { showUndoToast = false }
    undoDismissTask?.cancel()
    undoSnapshot = nil
    undoSession = nil
  }

  private var undoToast: some View {
    Button { performUndo() } label: {
      HStack(spacing: 8) {
        Image(systemName: "arrow.uturn.backward")
        Text("Undo time change")
          .font(.subheadline.weight(.medium))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.ultraThinMaterial, in: Capsule())
      .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Multi-Session Sheet

  private var barSessionsSheet: some View {
    NavigationView {
      List {
        ForEach(barTapSessions, id: \.id) { session in
          Button {
            showBarSessions = false
            selectSession(session)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(session.title.isEmpty ? "Untitled" : session.title)
                  .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              let start = session.startDate.formatted(date: .omitted, time: .shortened)
              let end = session.endDate.formatted(date: .omitted, time: .shortened)
              Text("\(start) – \(end)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
          }
          .buttonStyle(.plain)
        }
      }
      .listStyle(.plain)
      .navigationTitle("Sessions")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { showBarSessions = false }
        }
      }
    }
    .presentationDetents([.medium])
  }
}

// MARK: - Edge Fade + Blur

/// Fades the timeline out at the left and right edges.
private struct TimelineEdgeFade: ViewModifier {
  private let stops: CGFloat = 0.10  // fraction of width that fades

  func body(content: Content) -> some View {
    content.mask(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: stops),
          .init(color: .black, location: 1 - stops),
          .init(color: .clear, location: 1),
        ],
        startPoint: .leading, endPoint: .trailing
      )
    )
  }
}

struct TimeAdjustmentButtons: View {
  @Binding var selectedTime: Date

  @State private var hapticTrigger: Int = 0

  var body: some View {
    HStack {
      Button { adjust(by: -5 * 60) } label: {
        Image(systemName: "gobackward.5").font(.title2)
      }
      Spacer()
      Button { adjust(by: -1 * 60) } label: {
        ZStack {
          Image(systemName: "gobackward").font(.title2)
          Text("1").font(.caption).fontWeight(.semibold).fontDesign(.rounded).offset(y: 1.5)
        }
      }
      Spacer()
      Button {
        selectedTime = Date()
        hapticTrigger += 1
      } label: {
        Image(systemName: "stopwatch").font(.title2)
      }
      Spacer()
      Button { adjust(by: 1 * 60) } label: {
        ZStack {
          Image(systemName: "goforward").font(.title2)
          Text("1").font(.caption).fontWeight(.semibold).fontDesign(.rounded).offset(y: 1.5)
        }
      }
      Spacer()
      Button { adjust(by: 5 * 60) } label: {
        Image(systemName: "goforward.5").font(.title2)
      }
    }
    .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    .padding(.vertical, 3)
    .buttonStyle(BorderlessButtonStyle())
    .foregroundStyle(.blue)
  }

  private func adjust(by delta: TimeInterval) {
    selectedTime = min(selectedTime.addingTimeInterval(delta), Date())
    hapticTrigger += 1
  }
}
