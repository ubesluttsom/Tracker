import SwiftUI

struct EventFormView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        List {
            Section(header: Text("Details")) {
                TextField("Title", text: $viewModel.eventName)
                    .padding(.vertical, 4)
                    .onAppear {
                        UITextField.appearance().clearButtonMode = .whileEditing
                    }
                TextField("Notes", text: $viewModel.eventNotes)
                    .padding(.vertical, 4)
                    .onAppear {
                        UITextField.appearance().clearButtonMode = .whileEditing
                    }
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
                EventRecentsView(viewModel: viewModel)
            }
        }
        .refreshable {
            viewModel.fetchEvents()
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct TimeAdjustmentButtons: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                viewModel.adjustStartTime(by: -5 * 60)
            }) {
                Image(systemName: "gobackward.5")
                    .font(.title2)
            }
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
            Spacer()
            Button(action: {
                viewModel.startTime = Date()
                viewModel.updateTimerString()
            }) {
                Image(systemName: "stopwatch")
                    .font(.title2)
            }
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
            Spacer()
            Button(action: {
                viewModel.adjustStartTime(by: 5 * 60)
            }) {
                Image(systemName: "goforward.5")
                    .font(.title2)
            }
        }
        .padding([.vertical], 3)
        .buttonStyle(BorderlessButtonStyle())
        .foregroundStyle(.blue)
    }
}
