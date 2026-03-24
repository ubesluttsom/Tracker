import SwiftUI

struct TimerView: View {
  var viewModel: ContentViewModel

  var body: some View {
    VStack(spacing: 4) {
      HStack {
        Text(viewModel.showDailyTotal ? viewModel.dailyTotalString : viewModel.timerString)
          .font(.largeTitle)
          .padding()
          .monospaced()
          .foregroundColor(.primary)
          .contentTransition(.numericText())
          .onTapGesture {
            withAnimation {
              if !viewModel.showDailyTotal {
                viewModel.initDailyTotalTags()
              }
              viewModel.showDailyTotal.toggle()
            }
          }
        if viewModel.showTextField {
          if viewModel.timerRunning {
            Button(action: {
              viewModel.toggleTimer()
              viewModel.startTime = nil
              viewModel.updateTimerString()
              viewModel.fetchSessions()
            }) {
              Image(systemName: "stop.circle.fill")
                .font(.largeTitle)
                .padding([.top, .bottom, .trailing])
                .foregroundColor(.red)
            }
            .sensoryFeedback(.start, trigger: viewModel.timerRunning)
          } else {
            Button(action: {
              if viewModel.startTime == nil {
                viewModel.startTime = Date()
              }
              viewModel.toggleTimer()
            }) {
              Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .padding([.top, .bottom, .trailing])
                .foregroundColor(.green)
            }
            .sensoryFeedback(.stop, trigger: viewModel.timerRunning)
          }
        }
      }

      if viewModel.showDailyTotal && !viewModel.todayAvailableTags.isEmpty {
        FlowLayout(spacing: 6, alignment: .center, maxItemFraction: 0.9) {
          ForEach(viewModel.todayAvailableTags, id: \.self) { tag in
            TagChipView(
              tag: tag,
              color: viewModel.dailyTotalFilterTags.contains(tag) ? .blue : .gray
            )
            .onTapGesture {
              withAnimation {
                viewModel.toggleDailyTotalTag(tag)
              }
            }
          }
        }
        .padding(.horizontal)
        .frame(maxWidth: 280)
      }
    }.padding(.vertical)
  }
}
