import SwiftUI

struct SessionRecentsView: View {
    var viewModel: ContentViewModel

    var body: some View {
        ForEach(viewModel.sessions.prefix(5)) { session in
            SessionListItem(viewModel: viewModel, session: session)
                .onTapGesture {
                    viewModel.selectedSession = session
                }
        }
        .onDelete(perform: viewModel.deleteSession)

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
            Button(action: viewModel.fetchSessions) {
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
