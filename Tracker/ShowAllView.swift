import SwiftUI
import EventKit
import EventKitUI

struct ShowAllView: View {
    @ObservedObject var viewModel: ContentViewModel

    @State private var selectedEvent: EKEvent?
    @State private var showEventDetail = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.events, id: \.eventIdentifier) { event in
                    EventListItem(viewModel: viewModel, event: event)
                        .onTapGesture {
                            selectedEvent = event
                            showEventDetail.toggle()
                        }
                }
                .onDelete(perform: viewModel.deleteEvent)
                .font(.subheadline)
            }
            .onAppear(perform: viewModel.fetchEvents)
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, events: $viewModel.events, onDelete: viewModel.deleteEventFromDetail)
            }
            .navigationTitle("All Timers")
            .listStyle(.plain)
            .toolbar { EditButton() }
            .refreshable {
                viewModel.fetchEvents()
            }
        }
    }
}
