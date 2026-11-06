import Foundation

/// Représentation de l’app ; aucun type de swift-markdown ne quitte l’adaptateur.
struct MarkdownNode: Sendable {
    enum Kind: Sendable {
        case document, paragraph, text, emphasis, strong, inlineCode
        case heading(level: Int)
        case list(ordered: Bool, start: Int), listItem, blockQuote
        case codeBlock(language: String?)
        case softBreak, hardBreak, thematicBreak
        case link, image, rawHTMLLiteral
        case table, tableRow, tableCell(alignment: TableAlignment)
    }

    enum TableAlignment: Sendable { case none, left, center, right }

    let id: Int
    let kind: Kind
    let text: String
    let destination: String?
    let children: [MarkdownNode]

    init(id: Int, kind: Kind, text: String = "", destination: String? = nil,
         children: [MarkdownNode] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.destination = destination
        self.children = children
    }
}

struct HeadingAnchor: Sendable {
    let nodeID: Int
    let level: Int
    let title: String
    let fragment: String
}

/// Les plages utilisent des offsets UTF-16 ; le producteur vérifie leurs frontières Unicode
/// sur le texte concerné. Les séparateurs de blocs n’ont pas de nœud HTML à surligner.
struct VisibleTextRun: Sendable {
    let nodeID: Int
    let visibleUTF16Range: Range<Int>
    let nodeUTF16Range: Range<Int>
}

struct VisibleTextProjection: Sendable {
    let text: String
    let runs: [VisibleTextRun]
    let blockBoundaries: [Int]
}

struct ParsedDocument: Sendable {
    let documentID: UUID
    let snapshotGeneration: UInt64
    let root: MarkdownNode
    let headings: [HeadingAnchor]
    let visibleText: VisibleTextProjection
}
