import SwiftUI

struct SessionDetailView: View {
  var session: Session
  var onDelete: (Session) -> Void
  var onUpdate: ((Session) -> Void)?
  @Environment(\.dismiss) private var dismiss
  @State private var isEditing = false

  // Editing state
  @State private var editTitle: String = ""
  @State private var editNotes: String = ""
  @State private var editTags: [String] = []
  @State private var editStartDate: Date = Date()
  @State private var editEndDate: Date = Date()

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Details")) {
          if isEditing {
            TextField("Title", text: $editTitle)
              .padding(.vertical, 4)
            TextField("Notes", text: $editNotes)
              .padding(.vertical, 4)
            TagInputView(tags: $editTags)
          } else {
            LabeledContent("Title", value: session.title)
            if !session.notes.isEmpty {
              LabeledContent("Notes", value: session.notes)
            }
            TagListView(tags: session.tags, color: .blue)
          }
        }

        Section(header: Text("Time")) {
          if isEditing {
            DatePicker("Start", selection: $editStartDate)
            DatePicker("End", selection: $editEndDate, in: editStartDate..., displayedComponents: [.date, .hourAndMinute])
          } else {
            LabeledContent(
              "Start", value: session.startDate.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(
              "End", value: session.endDate.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Duration", value: session.formattedDuration)
          }
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
      .navigationTitle(isEditing ? "Edit Session" : session.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if isEditing {
            Button("Cancel") {
              isEditing = false
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          if isEditing {
            Button("Save") {
              saveEdits()
              isEditing = false
            }
            .bold()
            .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
          } else {
            HStack {
              Button("Edit") {
                loadEditState()
                isEditing = true
              }
              Button("Done") { dismiss() }
            }
          }
        }
      }
    }
  }

  private func loadEditState() {
    editTitle = session.title
    editNotes = session.notes
    editTags = session.tags
    editStartDate = session.startDate
    editEndDate = session.endDate
  }

  private func saveEdits() {
    session.title = editTitle.trimmingCharacters(in: .whitespaces)
    session.notes = editNotes
    session.tags = editTags
    session.startDate = editStartDate
    session.endDate = editEndDate
    onUpdate?(session)
  }
}
