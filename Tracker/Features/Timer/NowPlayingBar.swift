import SwiftUI

struct NowPlayingBar: View {
    @Bindable var viewModel: ContentViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
            Spacer()
            timerText
            Spacer()
            playStopButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .contextMenu {
            if viewModel.showDailyTotal && !viewModel.todayAvailableTags.isEmpty {
                ForEach(viewModel.todayAvailableTags, id: \.self) { tag in
                    Button {
                        withAnimation { viewModel.toggleDailyTotalTag(tag) }
                    } label: {
                        Label(
                            tag,
                            systemImage: viewModel.dailyTotalFilterTags.contains(tag)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }
                    .menuActionDismissBehavior(.disabled)
                }
            }
        }

    }

    // MARK: - Timer / Daily Total Text

    private var timerText: some View {
        HStack(spacing: 6) {
            Text(viewModel.showDailyTotal ? viewModel.dailyTotalString : viewModel.timerString)
                .font(.title2)
                .fontWeight(.medium)
                .monospaced()
                .foregroundColor(.primary)
                .contentTransition(.numericText())

            if viewModel.showDailyTotal && viewModel.isDailyTotalFiltered {
                Text("(*)")
                    .font(.title2)
                    .fontWeight(.medium)
                    .monospaced()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
        }
        .onTapGesture {
            withAnimation {
                if !viewModel.showDailyTotal {
                    viewModel.initDailyTotalTags()
                }
                viewModel.showDailyTotal.toggle()
            }
        }
    }

    // MARK: - Play / Stop Button

    private var playStopButton: some View {
        Group {
            if viewModel.timerRunning {
                stopButton
            } else {
                playButton
            }
        }
    }

    private var stopButton: some View {
        Button {
            viewModel.toggleTimer()
            viewModel.startTime = nil
            viewModel.updateTimerString()
            viewModel.fetchSessions()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
        .sensoryFeedback(.start, trigger: viewModel.timerRunning)
        .contextMenu {
            Button {
                viewModel.toggleTimer()
                viewModel.startTime = nil
                viewModel.updateTimerString()
                viewModel.fetchSessions()
            } label: {
                Label("Stop & Save", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                viewModel.discardActiveSession()
            } label: {
                Label("Stop & Discard", systemImage: "trash")
            }
            if viewModel.sessionTags.contains("Break") {
                Button {
                    viewModel.toggleTimer()
                    viewModel.startTime = nil
                    viewModel.updateTimerString()
                    viewModel.fetchSessions()
                    if viewModel.startTime == nil {
                        viewModel.startTime = Date()
                    }
                    viewModel.toggleTimer()
                    viewModel.sessionTags.removeAll { $0 == "Break" }
                } label: {
                    Label("End Break", systemImage: "cup.and.heat.waves.fill")
                }
            } else {
            Button {
                viewModel.toggleTimer()
                viewModel.startTime = nil
                viewModel.updateTimerString()
                viewModel.fetchSessions()
                if viewModel.startTime == nil {
                    viewModel.startTime = Date()
                }
                viewModel.toggleTimer()
                viewModel.sessionTags.append(contentsOf: ["Break"])
            } label: {
                Label("Break", systemImage: "cup.and.heat.waves.fill")
            }
        }
        }
    }

    private var playButton: some View {
        Button {
            if viewModel.startTime == nil {
                viewModel.startTime = Date()
            }
            viewModel.toggleTimer()
        } label: {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
        .sensoryFeedback(.stop, trigger: viewModel.timerRunning)
        .contextMenu {
            Button {
                if viewModel.startTime == nil {
                    viewModel.startTime = Date()
                }
                viewModel.toggleTimer()
            } label: {
                Label("Start Fresh", systemImage: "play")
            }
            Button {
                viewModel.startWithLastSession()
            } label: {
                Label("Continue Last Session", systemImage: "arrow.counterclockwise")
            }
        }
    }
}
