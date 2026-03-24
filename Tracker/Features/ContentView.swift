import SwiftUI

struct ContentView: View {
  @Bindable private var viewModel = ContentViewModel.shared

  var body: some View {
    NavigationView {
      ZStack {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation {
              viewModel.showTextField.toggle()
            }
          }

          VStack(spacing: 4) {
          TimerView(viewModel: viewModel).background(.clear)
          if viewModel.showTextField {
            TimerFormView(viewModel: viewModel)
          }
        }
        .sheet(isPresented: $viewModel.showAll) {
          ShowAllView(viewModel: viewModel)
        }
        .onAppear(perform: viewModel.fetchSessions)
        .sheet(item: $viewModel.selectedSession) { session in
          SessionDetailView(session: session, onDelete: viewModel.deleteSession, onUpdate: viewModel.updateSession)
        }
        .fullScreenCover(isPresented: $viewModel.showStatistics) {
          StatisticsView(sessions: viewModel.sessions)
        }
      }
    }
  }
}

#Preview {
  ContentView()
}
