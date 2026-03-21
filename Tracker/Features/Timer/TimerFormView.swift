import SwiftUI

struct TimerFormView: View {
  @Bindable var viewModel: ContentViewModel

  var body: some View {
    List {
      Section(header: Text("Details")) {
        TextField("Title", text: $viewModel.sessionName)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TextField("Notes", text: $viewModel.sessionNotes)
          .padding(.vertical, 4)
          .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
          }
        TagInputView(tags: $viewModel.sessionTags)
      }

      Section(header: Text("Start")) {
        HStack {
          Spacer()
          DatePicker(
            "",
            selection: Binding(
              get: { viewModel.startTime ?? Date() },
              set: { newValue in
                viewModel.startTime = newValue
                viewModel.updateTimerString()
              }
            ),
            displayedComponents: [.date, .hourAndMinute]
          )
          .labelsHidden()
          .datePickerStyle(.compact)
          .padding(.vertical, 4)
          Spacer()
        }
        TimeAdjustmentButtons(viewModel: viewModel)
          .padding(.vertical, 4)
      }

      Section(header: Text("Recents")) {
        SessionRecentsView(viewModel: viewModel)
      }
    }
    .refreshable {
      viewModel.fetchSessions()
    }
    .listStyle(InsetGroupedListStyle())
  }
}

struct TimeAdjustmentButtons: View {
  var viewModel: ContentViewModel

  var body: some View {
    HStack {
      Button(action: {
        viewModel.adjustStartTime(by: -5 * 60)
      }) {
        Image(systemName: "gobackward.5")
          .font(.title2)
      }
      .sensoryFeedback(.decrease, trigger: viewModel.startTime)
      Spacer()
      Button(action: {
        viewModel.adjustStartTime(by: -1 * 60)
      }) {
        ZStack {
          Image(systemName: "gobackward")
            .font(.title2)
          Text("1")
            .font(.caption)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .offset(y: 1.5)
        }
      }
      .sensoryFeedback(.decrease, trigger: viewModel.startTime)
      Spacer()
      Button(action: {
        viewModel.startTime = Date()
        viewModel.updateTimerString()
      }) {
        Image(systemName: "stopwatch")
          .font(.title2)
      }
      .sensoryFeedback(.impact(), trigger: viewModel.startTime)
      Spacer()
      Button(action: {
        viewModel.adjustStartTime(by: 1 * 60)
      }) {
        ZStack {
          Image(systemName: "goforward")
            .font(.title2)
          Text("1")
            .font(.caption)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .offset(y: 1.5)
        }
      }
      .sensoryFeedback(.increase, trigger: viewModel.startTime)
      Spacer()
      Button(action: {
        viewModel.adjustStartTime(by: 5 * 60)
      }) {
        Image(systemName: "goforward.5")
          .font(.title2)
      }
      .sensoryFeedback(.increase, trigger: viewModel.startTime)
    }
    .padding([.vertical], 3)
    .buttonStyle(BorderlessButtonStyle())
    .foregroundStyle(.blue)
  }
}
