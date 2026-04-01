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
    @FocusState private var textFieldFocused: Bool
    
    // Zoom-to-fit
    @State private var visibleHours: Double = 4.0
    @State private var pendingZoom: (start: Date, end: Date)? = nil
    
    // Undo
    @State private var undoSnapshot: (start: Date, end: Date)? = nil
    @State private var showUndoToast: Bool = false
    @State private var undoSession: Session? = nil
    @State private var undoDismissTask: Task<Void, Never>? = nil
    
    // Multi-session bar picker
    @State private var barTapSessions: [Session] = []
    @State private var showBarSessions: Bool = false
    
    // Session page navigation
    @State private var selectedPageID: String = ""
    
    private static let activePageID = "__active__"
    
    /// All today's sessions sorted chronologically, plus active session at the end.
    private var allPages: [(id: String, session: Session?)] {
        let sorted = viewModel.todaySessions.sorted { $0.startDate < $1.startDate }
        var pages = sorted.map { (id: $0.id.uuidString, session: Optional($0)) }
        if viewModel.timerRunning {
            pages.append((id: Self.activePageID, session: nil))
        }
        return pages
    }
    
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
                if editTarget != nil {
                    sessionPages
                } else {
                    List {
                        if viewModel.showTextField {
                            detailsSection
                            
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
                }
            }
            .sheet(isPresented: $showBarSessions) { barSessionsSheet }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    TimelinePickerView(
                        selectedTime: timelineBinding,
                        sessions: viewModel.todaySessions,
                        visibleHours: $visibleHours,
                        activeTags: viewModel.sessionTags,
                        activeSessionStart: viewModel.timerRunning ? viewModel.startTime : nil,
                        isInteracting: $timelineInteracting,
                        highlightedSessionIDs: highlightedSessionIDs,
                        isScrubbing: scrubField != nil,
                        alwaysExpanded: viewModel.timerRunning || editTarget != nil,
                        onBarTap: { bar in handleBarTap(bar) },
                        onEmptyTap: {
                            guard editTarget != nil else { return }
                            if case .saved(let session) = editTarget {
                                finishEditing(session)
                            } else {
                                withAnimation { editTarget = nil; scrubField = nil }
                                resetVisibleHours()
                            }
                        },
                        onNowTap: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                viewportCenter = Date()
                                visibleHours = 4.0
                            }
                            if viewModel.timerRunning {
                                withAnimation { editTarget = .active }
                                if let start = viewModel.startTime {
                                    zoomToFit(session: nil, start: start, end: Date())
                                }
                            } else {
                                withAnimation { editTarget = nil; scrubField = nil }
                            }
                        }
                    )
                    .padding(.vertical, 8)
                    
                    NowPlayingBar(viewModel: viewModel)
                }
                .background(.ultraThinMaterial)
            }
            
            // Undo toast
            if showUndoToast {
                undoToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
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
        .onChange(of: textFieldFocused) { _, focused in
            if focused && scrubField != nil {
                withAnimation { scrubField = nil }
            }
        }
        .onChange(of: viewportCenter) { _, newCenter in
            guard editTarget != nil, scrubField == nil else { return }
            if let session = viewModel.todaySessions.first(where: {
                $0.startDate <= newCenter && newCenter <= $0.endDate
            }) {
                if case .saved(let current) = editTarget, current.id == session.id { return }
                if case .saved(let outgoing) = editTarget {
                    saveEditsToSession(outgoing)
                }
                editTitle = session.title
                editNotes = session.notes
                editTags = session.tags
                editStartDate = session.startDate
                editEndDate = session.endDate
                undoSnapshot = (start: session.startDate, end: session.endDate)
                selectedPageID = session.id.uuidString
                withAnimation { editTarget = .saved(session) }
            } else if viewModel.timerRunning,
                      let start = viewModel.startTime,
                      start <= newCenter && newCenter <= Date() {
                guard editTarget != .active else { return }
                if case .saved(let outgoing) = editTarget {
                    saveEditsToSession(outgoing)
                }
                selectedPageID = Self.activePageID
                withAnimation { editTarget = .active }
            }
        }
        .onChange(of: timelineInteracting) { _, interacting in
            if !interacting, let zoom = pendingZoom {
                pendingZoom = nil
                zoomToFit(session: nil, start: zoom.start, end: zoom.end)
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
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
    }
    
    // MARK: - Session Pages
    
    private var sessionPages: some View {
        TabView(selection: $selectedPageID) {
            ForEach(allPages, id: \.id) { page in
                Group {
                    if let session = page.session {
                        savedSessionPage(session)
                    } else {
                        activeSessionPage
                    }
                }
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedPageID) { oldValue, newValue in
            handlePageChange(from: oldValue, to: newValue)
        }
    }
    
    private func savedSessionPage(_ session: Session) -> some View {
        List {
            Section { sessionActionRow(session: session) }
                .listSectionSpacing(12)

            Section {
                TextField("Title", text: $editTitle)
                    .font(.title)
                    .padding(.vertical, 4)
                    .focused($textFieldFocused)
                TextField("Notes", text: $editNotes)
                    .font(.body)
                    .padding(.vertical, 4)
                    .focused($textFieldFocused)
                TagInputView(tags: $editTags)
                timeScrubRow
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sessionActionRow(session: Session) -> some View {
        HStack(spacing: 12) {
            Spacer()
            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 10, height: 10)
                    .padding(10)
                    .background(Color.primary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            Button {
                viewModel.deleteSession(session)
                withAnimation { editTarget = nil; scrubField = nil }
                resetVisibleHours()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 10, height: 10)
                    .padding(10)
                    .background(Color.red.opacity(0.12), in: Circle())
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 16))
    }

    private var timeScrubRow: some View {
        HStack {
            Button { toggleScrub(.start) } label: {
                VStack(spacing: 2) {
                    Text(editStartDate.formatted(date: .omitted, time: .shortened))
                        .font(.body.weight(.medium))
                        .foregroundStyle(scrubField == .start ? .blue : .primary)
                    Image(systemName: "arrow.left.to.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(scrubField == .start ? Color.blue.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(formatDuration(editEndDate.timeIntervalSince(editStartDate)))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "capsule.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button { toggleScrub(.end) } label: {
                VStack(spacing: 2) {
                    Text(editEndDate.formatted(date: .omitted, time: .shortened))
                        .font(.body.weight(.medium))
                        .foregroundStyle(scrubField == .end ? .blue : .primary)
                    Image(systemName: "arrow.right.to.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(scrubField == .end ? Color.blue.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

  private var activeSessionPage: some View {
    List {
      Section {
        TextField("Title", text: $viewModel.sessionName)
              .font(.title)
          .padding(.vertical, 4)
          .focused($textFieldFocused)
        TextField("Notes", text: $viewModel.sessionNotes)
          .padding(.vertical, 4)
          .focused($textFieldFocused)
        TagInputView(tags: $viewModel.sessionTags)

        if let startTime = viewModel.startTime {
          HStack(spacing: 0) {
            Button {
              if scrubField == .start {
                withAnimation { scrubField = nil }
              } else {
                withAnimation { scrubField = .start }
              }
            } label: {
              VStack(spacing: 2) {
                  Text(editStartDate.formatted(date: .omitted, time: .shortened))
                      .font(.body.weight(.medium))
                      .foregroundStyle(scrubField == .start ? .blue : .primary)
                  Image(systemName: "arrow.left.to.line")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(scrubField == .start ? Color.blue.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 2) {
              Text(formatDuration(Date().timeIntervalSince(startTime)))
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
              Image(systemName: "capsule.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func handlePageChange(from oldID: String, to newID: String) {
    // Save edits for the outgoing session
    if case .saved(let session) = editTarget {
      saveEditsToSession(session)
    }
    scrubField = nil

    // Load the incoming session
    if newID == Self.activePageID {
      withAnimation { editTarget = .active }
      if let start = viewModel.startTime {
        zoomOrDefer(start: start, end: Date())
      }
    } else if let session = viewModel.todaySessions.first(where: { $0.id.uuidString == newID }) {
      editTitle = session.title
      editNotes = session.notes
      editTags = session.tags
      editStartDate = session.startDate
      editEndDate = session.endDate
      undoSnapshot = (start: session.startDate, end: session.endDate)
      withAnimation { editTarget = .saved(session) }
      zoomOrDefer(start: session.startDate, end: session.endDate)
    }
  }

  /// Zoom immediately if the user isn't dragging; otherwise defer until they lift their finger.
  private func zoomOrDefer(start: Date, end: Date) {
    if timelineInteracting {
      pendingZoom = (start: start, end: end)
    } else {
      zoomToFit(session: nil, start: start, end: end)
    }
  }

  // MARK: - Bar Tap Handling

  private func handleBarTap(_ bar: TagBar) {
    if bar.isActive {
      selectedPageID = Self.activePageID
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
    selectedPageID = session.id.uuidString
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
    .presentationDetents([.height(250), .medium])
    .presentationCornerRadius(20)
    .presentationDragIndicator(.visible)
    .presentationBackgroundInteraction(.enabled)
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
