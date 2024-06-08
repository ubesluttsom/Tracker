import SwiftUI
import EventKitUI

struct ContentView: View {
    @ObservedObject private var viewModel = ContentViewModel.shared

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
                
                VStack {
                    if !viewModel.showTextField {
                        Text(viewModel.eventName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    TimerView(viewModel: viewModel).background(.clear)
                    if viewModel.showTextField {
                        EventFormView(viewModel: viewModel)
                    }
                }
                .sheet(isPresented: $viewModel.showAll) {
                    ShowAllView(viewModel: viewModel)
                }
                .onAppear(perform: viewModel.fetchEvents)
                .onChange(of: viewModel.events, { _, _ in
                    viewModel.fetchEvents()
                })
                .sheet(item: $viewModel.selectedEvent) { event in
                    EventDetailView(event: event, events: $viewModel.events, onDelete: viewModel.deleteEventFromDetail)
                }
            }
        }
    }
}
