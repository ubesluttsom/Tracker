import SwiftUI
import EventKit

struct EventListItem: View {
    @ObservedObject var viewModel: ContentViewModel
    var event: EKEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title ?? "No Title").font(.headline)
                if let notes = event.notes, !notes.isEmpty {
                    Text("\(notes)")
                }
                Spacer()
            }
            Spacer()
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    let duration = CalendarHelper.duration(event: event)
                    Text("\(CalendarHelper.formatDuration(event: event))")
                        .font(.caption)
                        .colorInvert()
                        .padding([.vertical], 2)
                        .padding([.horizontal], 5)
                        .background(durationColor(duration: duration).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Spacer()
                    let start = event.startDate.formatted(date: .omitted, time: .shortened)
                    let stop = event.endDate.formatted(date: .omitted, time: .shortened)
                    Text("\(start) – \(stop)")
                }.foregroundColor(.secondary)
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding()
        .swipeActions(edge: .leading) {
            Button(action: {
                viewModel.eventName = event.title
                viewModel.eventNotes = event.notes ?? ""
            }){
                Image(systemName: "list.clipboard")
            }
        }
        .tint(.indigo)
    }
    
    private func durationColor(duration: TimeInterval) -> Color {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours >= 1 {
            return Color.green
        } else if minutes >= 15 {
            return Color.blue
        } else if minutes >= 10 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
}
