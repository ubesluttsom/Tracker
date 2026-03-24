import SwiftUI

struct SessionRecentsView: View {
    var viewModel: ContentViewModel

    @State private var pendingMerge: (keep: Session, remove: Session)?
    @State private var showMergeWarning = false
    @State private var copyTargetSession: Session?

    private var isInCopyMode: Bool { copyTargetSession != nil }

    var body: some View {
        if let target = copyTargetSession {
            HStack {
                Image(systemName: "doc.on.doc")
                Text("Tap a session to copy its data into **\(target.title)**")
                Spacer()
                Button("Cancel") {
                    withAnimation { copyTargetSession = nil }
                }
                .font(.subheadline)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .padding(.horizontal)
        }

        let recentSessions = Array(viewModel.sessions.prefix(5))
        ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
            SessionListItem(viewModel: viewModel, session: session)
                .onTapGesture {
                    if let target = copyTargetSession {
                        if session.id != target.id {
                            viewModel.copySessionData(from: session, to: target)
                        }
                        withAnimation { copyTargetSession = nil }
                    } else {
                        viewModel.selectedSession = session
                    }
                }
                .opacity(isInCopyMode && copyTargetSession?.id == session.id ? 0.5 : 1)
                .blur(radius: isInCopyMode && copyTargetSession?.id == session.id ? 4 : 0)
                .contextMenu {
                    if !isInCopyMode {
                        sessionContextMenu(for: session, at: index, in: recentSessions)
                    }
                }
        }
        .onDelete(perform: viewModel.deleteSession)
        .animation(.easeInOut(duration: 0.25), value: isInCopyMode)
        .alert("Large Time Gap", isPresented: $showMergeWarning) {
            Button("Merge Anyway", role: .destructive) {
                if let merge = pendingMerge {
                    viewModel.mergeSessions(keep: merge.keep, remove: merge.remove)
                }
                pendingMerge = nil
            }
            Button("Cancel", role: .cancel) {
                pendingMerge = nil
            }
        } message: {
            if let merge = pendingMerge {
                let gap = viewModel.timeGap(between: merge.keep, merge.remove)
                let minutes = Int(gap) / 60
                Text("There is a \(minutes)-minute gap between these sessions. Merge anyway?")
            }
        }

        HStack {
            Spacer()
            Button(action: {
                viewModel.showAll = true
            }) {
                Text("View All")
            }
            Spacer()
            Text("·").foregroundStyle(.gray.secondary)
            Spacer()
            Button(action: viewModel.openCalendarApp) {
                Text("Open Calendar")
            }
            Spacer()
            Text("·").foregroundStyle(.gray.secondary)
            Spacer()
            Button(action: viewModel.fetchSessions) {
                Text("Refresh")
            }
            Spacer()
            Text("·").foregroundStyle(.gray.secondary)
            Spacer()
            Button(action: { viewModel.showStatistics = true }) {
                Text("Statistics")
            }
            Spacer()
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundStyle(.blue.secondary)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding()
    }

    @ViewBuilder
    private func sessionContextMenu(for session: Session, at index: Int, in sessions: [Session]) -> some View {
        let above: Session? = index > 0 ? sessions[index - 1] : nil
        let below: Session? = index < sessions.count - 1 ? sessions[index + 1] : nil

        if let above, viewModel.canMergeSessions(session, above) {
            Button {
                attemptMerge(keep: session, remove: above)
            } label: {
                Label("Merge with Above", systemImage: "arrow.up")
            }
        }

        if let below, viewModel.canMergeSessions(session, below) {
            Button {
                attemptMerge(keep: session, remove: below)
            } label: {
                Label("Merge with Below", systemImage: "arrow.down")
            }
        }

        Button {
            withAnimation { copyTargetSession = session }
        } label: {
            Label("Copy Data from …", systemImage: "doc.on.doc")
        }
    }

    private func attemptMerge(keep: Session, remove: Session) {
        let gap = viewModel.timeGap(between: keep, remove)
        if gap > 15 * 60 {
            pendingMerge = (keep: keep, remove: remove)
            showMergeWarning = true
        } else {
            viewModel.mergeSessions(keep: keep, remove: remove)
        }
    }
}
