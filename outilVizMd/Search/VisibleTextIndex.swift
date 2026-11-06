import Foundation

/// Même contenu que le rendu ; offsets UTF-16, matches limités aux frontières Unicode.
/// Les séparateurs de blocs restent cherchables mais n’émettent pas de marque HTML.
struct VisibleTextIndex: Sendable {
    let projection: VisibleTextProjection
    init(_ projection: VisibleTextProjection) { self.projection = projection }
}

struct SearchSegment: Sendable {
    let nodeID: Int
    let range: Range<Int>
    let occurrence: Int
    let isFirst: Bool
}

struct SearchMatch: Sendable {
    let range: Range<Int>
    let segments: [SearchSegment]
}
