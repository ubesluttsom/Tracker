import SwiftUI

struct ShowAllView: View {
    @Bindable var viewModel: ContentViewModel

    @State private var selectedSession: Session?

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.sessions) { session in
                    SessionListItem(viewModel: viewModel, session: session)
                        .onTapGesture {
                            selectedSession = session
                        }
                }
                .onDelete(perform: viewModel.deleteSession)
                .font(.subheadline)
            }
            .onAppear(perform: viewModel.fetchSessions)
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, onDelete: viewModel.deleteSession, onUpdate: viewModel.updateSession)
            }
            .navigationTitle("All Timers")
            .listStyle(.plain)
            .toolbar { EditButton() }
            .refreshable {
                viewModel.fetchSessions()
            }
        }
    }
}
