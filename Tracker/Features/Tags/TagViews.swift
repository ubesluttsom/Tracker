import SwiftUI

/// A single read-only tag chip. Truncates with … when the enclosing
/// FlowLayout constrains its width via maxItemFraction.
struct TagChipView: View {
    let tag: String
    var color: Color = .gray

    var body: some View {
        Text(tag)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// A flow of read-only tag chips with automatic truncation for long tags.
struct TagListView: View {
    let tags: [String]
    var spacing: CGFloat = 4
    var color: Color = .gray
    var maxItemFraction: CGFloat? = 0.95

    var body: some View {
        if !tags.isEmpty {
            FlowLayout(spacing: spacing, maxItemFraction: maxItemFraction) {
                ForEach(tags, id: \.self) { tag in
                    TagChipView(tag: tag, color: color)
                }
            }
        }
    }
}
