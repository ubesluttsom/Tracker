import SwiftUI

struct SessionDetailView: View {
  var session: Session
  var onDelete: (Session) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Details")) {
          LabeledContent("Title", value: session.title)
          if !session.notes.isEmpty {
            LabeledContent("Notes", value: session.notes)
          }
          TagListView(tags: session.tags, color: .blue)
        }

        Section(header: Text("Time")) {
          LabeledContent(
            "Start", value: session.startDate.formatted(date: .abbreviated, time: .shortened))
          LabeledContent(
            "End", value: session.endDate.formatted(date: .abbreviated, time: .shortened))
          LabeledContent("Duration", value: session.formattedDuration)
        }

        Section {
          Button(role: .destructive) {
            onDelete(session)
            dismiss()
          } label: {
            HStack {
              Spacer()
              Text("Delete Session")
              Spacer()
            }
          }
        }
      }
      .navigationTitle(session.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
