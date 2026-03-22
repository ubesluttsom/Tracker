import Foundation

enum Period: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct AggregatedRow: Identifiable {
    let id: String
    let label: String
    let totalDuration: TimeInterval

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

@Observable
class StatisticsViewModel {
    var sessions: [Session]
    var selectedTag: String?
    var selectedPeriod: Period = .day

    var availableTags: [String] {
        Array(Set(sessions.flatMap(\.tags))).sorted()
    }

    var filteredSessions: [Session] {
        guard let tag = selectedTag else { return sessions }
        return sessions.filter { $0.tags.contains(tag) }
    }

    var aggregatedRows: [AggregatedRow] {
        let calendar = Calendar.current
        let grouped: [DateComponents: [Session]]

        switch selectedPeriod {
        case .day:
            grouped = Dictionary(grouping: filteredSessions) {
                calendar.dateComponents([.year, .month, .day], from: $0.startDate)
            }
        case .week:
            grouped = Dictionary(grouping: filteredSessions) {
                calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.startDate)
            }
        case .month:
            grouped = Dictionary(grouping: filteredSessions) {
                calendar.dateComponents([.year, .month], from: $0.startDate)
            }
        }

        return grouped.map { components, sessions in
            let total = sessions.reduce(0) { $0 + $1.duration }
            let label = formatLabel(for: components, period: selectedPeriod)
            let id = sortKey(for: components, period: selectedPeriod)
            return AggregatedRow(id: id, label: label, totalDuration: total)
        }
        .sorted { $0.id > $1.id }
    }

    var totalDuration: TimeInterval {
        aggregatedRows.reduce(0) { $0 + $1.totalDuration }
    }

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    init(sessions: [Session]) {
        self.sessions = sessions
    }

    private func sortKey(for components: DateComponents, period: Period) -> String {
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        switch period {
        case .day:
            return String(format: "%04d-%02d-%02d", y, m, d)
        case .week:
            let yw = components.yearForWeekOfYear ?? 0
            let w = components.weekOfYear ?? 0
            return String(format: "%04d-W%02d", yw, w)
        case .month:
            return String(format: "%04d-%02d", y, m)
        }
    }

    private func formatLabel(for components: DateComponents, period: Period) -> String {
        let calendar = Calendar.current

        switch period {
        case .day:
            guard let date = calendar.date(from: components) else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)

        case .week:
            guard let monday = calendar.date(from: components) else { return "Unknown" }
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: monday)
            let end = formatter.string(from: sunday)
            return "\(start) – \(end)"

        case .month:
            guard let date = calendar.date(from: components) else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}
