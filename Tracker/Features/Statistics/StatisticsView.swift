import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: StatisticsViewModel

    init(sessions: [Session]) {
        self.viewModel = StatisticsViewModel(sessions: sessions)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tagPicker
                periodPicker

                if viewModel.filteredSessions.isEmpty {
                    emptyState
                } else {
                    aggregatedList
                }
            }
            .background(Color.black)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tagPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChipView(
                    tag: "All",
                    color: viewModel.selectedTag == nil ? .blue : .gray
                )
                .onTapGesture { viewModel.selectedTag = nil }

                ForEach(viewModel.availableTags, id: \.self) { tag in
                    TagChipView(
                        tag: tag,
                        color: viewModel.selectedTag == tag ? .blue : .gray
                    )
                    .onTapGesture { viewModel.selectedTag = tag }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No sessions found")
                .foregroundStyle(.secondary)
            if viewModel.selectedTag != nil {
                Text("Try selecting a different tag")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var aggregatedList: some View {
        List {
            Section {
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(viewModel.formattedTotalDuration)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .listRowBackground(Color.black)
            }

            Section {
                ForEach(viewModel.aggregatedRows) { row in
                    HStack {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.formattedDuration)
                            .monospacedDigit()
                    }
                    .listRowBackground(Color.black)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
