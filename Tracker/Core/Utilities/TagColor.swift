import SwiftUI

/// Deterministic tag → color mapping using a stable hash.
/// Reusable across the app wherever tags need consistent coloring.
enum TagColor {
    static let palette: [Color] = [
        .blue, .purple, .pink, .red, .orange,
        .yellow, .green, .teal, .cyan, .indigo,
    ]

    static func color(for tag: String) -> Color {
        let hash = tag.utf8.reduce(5381) { ($0 &<< 5) &+ $0 &+ Int($1) }
        return palette[abs(hash) % palette.count]
    }
}
