import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var input: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        EditableTagChip(tag: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            TextField("Tags", text: $input)
                .padding(.vertical, 4)
                .onSubmit {
                    addTag()
                }
        }
    }

    private func addTag() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            input = ""
            return
        }
        tags.append(trimmed)
        input = ""
    }
}

/// A tag chip with an X button for removal. Used in editable contexts.
struct EditableTagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

/// A simple flow layout that wraps children to the next line when they
/// don't fit. iOS 16+ has native Layout protocol support for this.
/// A flow layout that wraps children to the next line when they don't fit.
///
/// - `spacing`: gap between items and rows
/// - `alignment`: horizontal alignment of each row (.leading, .trailing, .center)
/// - `maxItemFraction`: optional cap on each item's width as a fraction of the
///   container (e.g. 0.4 = 40%). Prevents long text from hogging the row.
///   Text views with `lineLimit(1)` will truncate with … when this kicks in.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading
    var maxItemFraction: CGFloat? = 0.95

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        let itemProposal = cappedProposal(containerWidth: bounds.width)
        for (index, position) in result.positions.enumerated() {
            let rowIndex = result.rowForIndex[index]
            let rowWidth = result.rowWidths[rowIndex]
            let offset: CGFloat = switch alignment {
            case .trailing: bounds.width - rowWidth
            case .center: (bounds.width - rowWidth) / 2
            default: 0
            }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x + offset, y: bounds.minY + position.y),
                proposal: itemProposal
            )
        }
    }

    /// Returns a ProposedViewSize that caps width if maxItemFraction is set.
    private func cappedProposal(containerWidth: CGFloat) -> ProposedViewSize {
        if let fraction = maxItemFraction {
            return ProposedViewSize(width: containerWidth * fraction, height: nil)
        }
        return .unspecified
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
        var rowWidths: [CGFloat]
        var rowForIndex: [Int]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        let itemProposal = cappedProposal(containerWidth: maxWidth)
        var positions: [CGPoint] = []
        var rowWidths: [CGFloat] = []
        var rowForIndex: [Int] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var currentRow = 0

        for subview in subviews {
            let size = subview.sizeThatFits(itemProposal)
            if x + size.width > maxWidth, x > 0 {
                rowWidths.append(x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
                currentRow += 1
            }
            positions.append(CGPoint(x: x, y: y))
            rowForIndex.append(currentRow)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        rowWidths.append(x > 0 ? x - spacing : 0)

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: maxWidth, height: y + rowHeight),
            rowWidths: rowWidths,
            rowForIndex: rowForIndex
        )
    }
}
