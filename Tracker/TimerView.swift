import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        HStack {
            Text(viewModel.timerString)
                .font(.largeTitle)
                .padding()
                .monospaced()
                .foregroundColor(.primary)
                .onTapGesture {
                    withAnimation {
                        viewModel.showTextField.toggle()
                    }
                }
            if viewModel.showTextField {
                if viewModel.timerRunning {
                    Button(action: {
                        viewModel.toggleTimer()
                        viewModel.startTime = nil
                        viewModel.updateTimerString()
                        viewModel.fetchEvents()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.largeTitle)
                            .padding([.top, .bottom, .trailing])
                            .foregroundColor(.red)
                    }
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
                }
            }
        }
    }
}
