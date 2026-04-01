import SwiftData
import SwiftUI

// MARK: - Data Types

struct TagBar: Identifiable, Equatable {
    let id: String
    let tag: String
    let label: String
    let startDate: Date
    let endDate: Date
    let tagIndex: Int
    let isActive: Bool
    let mergePoints: [Date]
    let sessionIDs: [UUID]
}

private struct SessionSlice {
    let startDate: Date
    let endDate: Date
    let tags: [String]
    let isActive: Bool
    let title: String
    let sessionID: UUID?
}

private struct RawBar {
    let tag: String
    let label: String
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    let mergePoints: [Date]
    let stableID: String
    let sessionIDs: [UUID]
}

// MARK: - View

struct TagTimelineBarsView: View {
    let sessions: [Session]
    let activeTags: [String]
    let activeSessionStart: Date?
    let windowStart: Date
    let windowEnd: Date
    let pps: Double
    let baseline: CGFloat
    let now: Date

    // ┌──────────────────────────────────────────────────┐
    // │  TWEAKABLE CONSTANTS — start here when tuning    │
    // └──────────────────────────────────────────────────┘
    static let barHeight: CGFloat = 6
    static let expandedBarHeight: CGFloat = 18
    static let barGap: CGFloat = 4       // vertical gap between tag rows
    static let expandedBarGap: CGFloat = 6
    static let topOffset: CGFloat = 6    // gap between tick baseline and first bar row
    private let cornerRadius: CGFloat = barHeight/2
    private let expandedCornerRadius: CGFloat = expandedBarHeight/2
    private let barInset: CGFloat = 2    // horizontal inset on each bar edge

    private let mergeTolerance: TimeInterval = 120
    private let rowOverlapTolerance: TimeInterval = 60

    var isExpanded: Bool = false
    var visibleWidth: CGFloat = 0
    var highlightedSessionIDs: Set<UUID> = []
    var onBarTap: ((TagBar) -> Void)?

    private static let untagged = ""

    var body: some View {
        let bars = computeTagBars()
        let currentBarHeight = isExpanded ? Self.expandedBarHeight : Self.barHeight
        let currentGap = isExpanded ? Self.expandedBarGap : Self.barGap
        let baseY = baseline - Self.topOffset - currentBarHeight / 2
        let expandedCornerRadius: CGFloat = isExpanded ? expandedCornerRadius : cornerRadius
        ZStack(alignment: .topLeading) {
            ForEach(bars) { bar in
                let rawX = bar.startDate.timeIntervalSince(windowStart) * pps
                let rawW = bar.endDate.timeIntervalSince(bar.startDate) * pps
                let x = rawX + barInset
                let w = max(rawW - 2 * barInset, 2)

                let hasHighlight = !highlightedSessionIDs.isEmpty
                let isHighlighted = !highlightedSessionIDs.isDisjoint(with: bar.sessionIDs)
                let dimFactor: Double = hasHighlight && !isHighlighted ? 0.3 : 1.0
                let color = bar.tag.isEmpty
                    ? Color.gray.opacity((bar.isActive ? 0.4 : 0.15) * dimFactor)
                    : TagColor.color(for: bar.tag).opacity((bar.isActive ? 0.5 : 0.3) * dimFactor)

                let rowOffset = -CGFloat(bar.tagIndex) * (currentBarHeight + currentGap)

                let labelText = bar.tag.isEmpty ? bar.label : bar.tag
                let labelColor = bar.tag.isEmpty
                    ? Color.gray
                    : TagColor.color(for: bar.tag)
                let stickyPadding = max(4, -rawX + 4)

                Group {
                    if bar.isActive {
                        UnevenRoundedRectangle(
                            topLeadingRadius: expandedCornerRadius,
                            bottomLeadingRadius: expandedCornerRadius,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(color)
                    } else {
                        RoundedRectangle(cornerRadius: expandedCornerRadius)
                            .fill(color)
                    }
                }
                    .frame(width: w, height: currentBarHeight)
                    .overlay(alignment: .leading) {
                        if !labelText.isEmpty {
                            Text(labelText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(labelColor)
                                .lineLimit(1)
                                .padding(.leading, stickyPadding)
                                .opacity(isExpanded ? 1 : 0)
                        }
                    }
                    .clipped()
                    .overlay {
                        if bar.isActive {
                            UnevenRoundedRectangle(
                                topLeadingRadius: expandedCornerRadius,
                                bottomLeadingRadius: expandedCornerRadius,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 0
                            )
                            .fill(color)
                            .modifier(PulseOpacity())
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isExpanded {
                            onBarTap?(bar)
                        }
                    }
                    .modifier(BarPosition(x: x + w / 2, baseY: baseY, rowOffset: rowOffset))
                    .animation(.spring(duration: 0.4, bounce: 0.12), value: rowOffset)
                    .animation(.spring(duration: 0.4, bounce: 0.12), value: isExpanded)

                ForEach(bar.mergePoints.indices, id: \.self) { i in
                    let mpx = bar.mergePoints[i].timeIntervalSince(windowStart) * pps
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 0.5, height: currentBarHeight)
                        .modifier(BarPosition(x: mpx, baseY: baseY, rowOffset: rowOffset))
                        .animation(.spring(duration: 0.4, bounce: 0.12), value: rowOffset)
                        .animation(.spring(duration: 0.4, bounce: 0.12), value: isExpanded)
                }
            }
        }
    }

    // MARK: - Height Calculation

    static func maxTagCount(
        sessions: [Session], activeTags: [String], hasActiveSession: Bool
    ) -> Int {
        var realTags = Set<String>()
        var hasUntagged = false
        for session in sessions {
            if session.tags.isEmpty {
                hasUntagged = true
            } else {
                realTags.formUnion(session.tags)
            }
        }
        if hasActiveSession && activeTags.isEmpty {
            hasUntagged = true
        }
        realTags.formUnion(activeTags)
        return max(realTags.count + (hasUntagged ? 1 : 0), 1)
    }

    static func barAreaHeight(maxTagCount: Int, isExpanded: Bool = false) -> CGFloat {
        let h = isExpanded ? expandedBarHeight : barHeight
        let gap = isExpanded ? expandedBarGap : barGap
        return topOffset + CGFloat(maxTagCount) * (h + gap)
    }

    // MARK: - Pipeline

    private func computeTagBars() -> [TagBar] {
        var slices = sessions.map { session in
            SessionSlice(
                startDate: session.startDate,
                endDate: session.endDate,
                tags: session.tags.isEmpty ? [Self.untagged] : session.tags,
                isActive: false,
                title: session.title,
                sessionID: session.id
            )
        }

        if let start = activeSessionStart {
            let tags = activeTags.isEmpty ? [Self.untagged] : activeTags
            slices.append(SessionSlice(
                startDate: start,
                endDate: now,
                tags: tags,
                isActive: true,
                title: "",
                sessionID: nil
            ))
        }

        guard !slices.isEmpty else { return [] }

        let rawBars = generateRawBars(slices)
        return assignRows(rawBars)
    }

    /// For each unique tag, merge overlapping/adjacent intervals into spans.
    private func generateRawBars(_ slices: [SessionSlice]) -> [RawBar] {
        let allTags = Array(Set(slices.flatMap(\.tags)))
        var rawBars: [RawBar] = []

        for tag in allTags {
            let matching = slices
                .filter { $0.tags.contains(tag) }
                .sorted { $0.startDate < $1.startDate }

            let canMerge = !tag.isEmpty
            var spans: [(start: Date, end: Date, isActive: Bool, mergePoints: [Date], label: String, sessionIDs: [UUID])] = []

            for slice in matching {
                let sliceIDs: [UUID] = slice.sessionID.map { [$0] } ?? []
                if canMerge,
                   let last = spans.last,
                   slice.startDate.timeIntervalSince(last.end) <= mergeTolerance
                {
                    var points = last.mergePoints
                    if slice.startDate >= last.end {
                        points.append(slice.startDate)
                    }
                    spans[spans.count - 1] = (
                        start: last.start,
                        end: max(last.end, slice.endDate),
                        isActive: last.isActive || slice.isActive,
                        mergePoints: points,
                        label: last.label.isEmpty ? slice.title : last.label,
                        sessionIDs: last.sessionIDs + sliceIDs
                    )
                } else {
                    spans.append((slice.startDate, slice.endDate, slice.isActive, [], slice.title, sliceIDs))
                }
            }

            var historicalIndex = 0
            for span in spans {
                let stableID: String
                if span.isActive {
                    stableID = "\(tag)_active"
                } else {
                    stableID = "\(tag)_\(historicalIndex)"
                    historicalIndex += 1
                }
                rawBars.append(RawBar(
                    tag: tag,
                    label: span.label,
                    startDate: span.start,
                    endDate: span.end,
                    isActive: span.isActive,
                    mergePoints: span.mergePoints,
                    stableID: stableID,
                    sessionIDs: span.sessionIDs
                ))
            }
        }

        return rawBars
    }

    /// Greedy row packing — bars that don't overlap in time share rows.
    /// Active bars are placed first (preserving activeTags order) so they
    /// always occupy the topmost rows.
    private func assignRows(_ bars: [RawBar]) -> [TagBar] {
        let activeBars = bars
            .filter(\.isActive)
            .sorted { a, b in
                let ai = activeTags.firstIndex(of: a.tag) ?? Int.max
                let bi = activeTags.firstIndex(of: b.tag) ?? Int.max
                return ai < bi
            }

        let restBars = bars
            .filter { !$0.isActive }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.endDate != $1.endDate { return $0.endDate > $1.endDate }
                return $0.tag < $1.tag
            }

        // Each row tracks occupied time ranges.
        var rows: [[ClosedRange<TimeInterval>]] = []
        var result: [TagBar] = []

        func lowestAvailableRow(for bar: RawBar) -> Int {
            let s = bar.startDate.timeIntervalSinceReferenceDate + rowOverlapTolerance
            let e = bar.endDate.timeIntervalSinceReferenceDate - rowOverlapTolerance
            guard s <= e else { return 0 }
            let range = s...e
            for (i, row) in rows.enumerated() {
                if !row.contains(where: { $0.overlaps(range) }) {
                    return i
                }
            }
            return rows.count
        }

        func place(_ bar: RawBar, at row: Int) {
            let s = bar.startDate.timeIntervalSinceReferenceDate
            let e = bar.endDate.timeIntervalSinceReferenceDate
            while rows.count <= row { rows.append([]) }
            if s <= e { rows[row].append(s...e) }
            result.append(TagBar(
                id: bar.stableID,
                tag: bar.tag,
                label: bar.label,
                startDate: bar.startDate,
                endDate: bar.endDate,
                tagIndex: row,
                isActive: bar.isActive,
                mergePoints: bar.mergePoints,
                sessionIDs: bar.sessionIDs
            ))
        }

        // Active bars first — they share the active session's time span,
        // so they naturally get consecutive rows 0, 1, 2, ...
        for bar in activeBars {
            let row = lowestAvailableRow(for: bar)
            place(bar, at: row)
        }

        // Non-active bars float up to the lowest available row.
        for bar in restBars {
            let row = lowestAvailableRow(for: bar)
            place(bar, at: row)
        }

        return result
    }
}

// MARK: - Pulse Animation

private struct PulseOpacity: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.6 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

// MARK: - Bar Position (Animatable)

/// Only `rowOffset` is in `animatableData` — vertical row changes get
/// interpolated while `x` and `baseY` update instantly every frame.
private struct BarPosition: ViewModifier, Animatable {
    var x: CGFloat
    var baseY: CGFloat
    var rowOffset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(baseY, rowOffset) }
        set { baseY = newValue.first; rowOffset = newValue.second }
    }

    func body(content: Content) -> some View {
        content.position(x: x, y: baseY + rowOffset)
    }
}
