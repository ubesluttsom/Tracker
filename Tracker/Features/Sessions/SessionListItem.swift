import SwiftUI

struct SessionListItem: View {
  var viewModel: ContentViewModel
  var session: Session

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(session.title).font(.headline)
        Spacer()
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        let stop = session.endDate.formatted(date: .omitted, time: .shortened)
        Text("\(start) – \(stop)")
          .foregroundColor(.secondary)
      }
      Spacer()
      if !session.notes.isEmpty {
        Text("\(session.notes)")
      }
      Spacer()
      FlowLayout(spacing: 4, maxItemFraction: 0.9) {
        TagChipView(
          tag: session.formattedDuration,
          color: durationColor(duration: session.duration)
        )
        ForEach(session.tags, id: \.self) { tag in
          TagChipView(tag: tag)
        }
      }
    }
    .listRowBackground(Color.clear)
    .listRowInsets(EdgeInsets())
    .padding()
    .swipeActions(edge: .leading) {
      Button(action: {
        viewModel.sessionName = session.title
        viewModel.sessionNotes = session.notes
        viewModel.sessionTags = session.tags
      }) {
        Image(systemName: "list.clipboard")
      }
    }
    .tint(.indigo)
  }

  private func durationColor(duration: TimeInterval) -> Color {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    if hours >= 1 {
      return .green
    } else if minutes >= 15 {
      return .blue
    } else if minutes >= 10 {
      return .yellow
    } else {
      return .red
    }
  }
}
