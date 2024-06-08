import SwiftUI

struct EventRecentsView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        // Text("Recents")
        //     .font(.headline)
        //     .frame(maxWidth: .infinity, alignment: .leading)
        //     .listRowBackground(Color.clear)
        //     .listRowInsets(EdgeInsets())
        //     .padding()
        
        ForEach(viewModel.events.prefix(5), id: \.eventIdentifier) { event in
            EventListItem(viewModel: viewModel, event: event)
                .onTapGesture {
                    viewModel.selectedEvent = event
                    viewModel.showEventDetail.toggle()
                }
        }
        .onDelete(perform: viewModel.deleteEvent)
        
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
            Button(action: viewModel.fetchEvents) {
                Text("Refresh")
            }
            Spacer()
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundStyle(.blue.secondary)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding()
    }
}
