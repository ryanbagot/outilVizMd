import Foundation
import Markdown

actor MarkdownParser {
    func parse(_ snapshot: DocumentSnapshot) -> ParsedDocument {
        parse(text: snapshot.text, documentID: snapshot.documentID, generation: snapshot.generation)
    }

    func parse(text: String, documentID: UUID, generation: UInt64) -> ParsedDocument {
        let document = Document(parsing: text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var builder = Builder()
        let root = builder.convert(document)
        return ParsedDocument(documentID: documentID, snapshotGeneration: generation, root: root, headings: builder.headings, visibleText: VisibleTextProjector.project(root))
    }

    private struct Builder {
        var nextID = 0
        var headings: [HeadingAnchor] = []
        var slugs: [String: Int] = [:]

        mutating func convert(_ markup: any Markup) -> MarkdownNode {
            let id = nextID
            nextID += 1
            var children: [MarkdownNode] = markup is Table ? [] : markup.children.map { convert($0) }
            let kind: MarkdownNode.Kind
            var text = ""
            var destination: String?
            switch markup {
            case let value as Text: kind = .text; text = value.string
            case let value as InlineCode: kind = .inlineCode; text = value.code
            case let value as CodeBlock: kind = .codeBlock(language: value.language); text = value.code
            case let value as HTMLBlock: kind = .rawHTMLLiteral; text = value.rawHTML
            case let value as InlineHTML: kind = .rawHTMLLiteral; text = value.rawHTML
            case let value as Heading:
                kind = .heading(level: value.level)
                let title = children.map(Self.plain).joined()
                var slug = title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX")).lowercased()
                slug = slug.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
                slug = slug.split(separator: "-").joined(separator: "-")
                if slug.isEmpty { slug = "titre" }
                slugs[slug, default: 0] += 1
                let number = slugs[slug, default: 1]
                headings.append(HeadingAnchor(nodeID: id, level: value.level, title: title, fragment: slug + (number > 1 ? "-\(number)" : "")))
            case is Paragraph: kind = .paragraph
            case is Emphasis: kind = .emphasis
            case is Strong: kind = .strong
            case let value as OrderedList: kind = .list(ordered: true, start: Int(clamping: value.startIndex))
            case is UnorderedList: kind = .list(ordered: false, start: 1)
            case is ListItem: kind = .listItem
            case is BlockQuote: kind = .blockQuote
            case is SoftBreak: kind = .softBreak; text = " "
            case is LineBreak: kind = .hardBreak; text = "\n"
            case is ThematicBreak: kind = .thematicBreak
            case let value as Link: kind = .link; destination = value.destination
            case let value as Image: kind = .image; destination = value.source; text = children.map(Self.plain).joined()
            case let table as Table:
                kind = .table
                // Les wrappers internes de table n’exposent aucun nœud du moteur.
                let headID = nextID
                nextID += 1
                let header = MarkdownNode(id: headID, kind: .tableRow, children: table.head.children.map { convert($0) })
                children = [header] + table.body.children.map { convert($0) }
            case is Table.Row: kind = .tableRow
            case is Table.Cell: kind = .tableCell(alignment: .none)
            default: kind = .document
            }
            return MarkdownNode(id: id, kind: kind, text: text, destination: destination, children: children)
        }

        private static func plain(_ node: MarkdownNode) -> String {
            node.text + node.children.map(plain).joined()
        }
    }
}

enum VisibleTextProjector {
    static func inlineText(_ text: String) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        var previousSpace = false
        for byte in text.utf8 {
            let space = byte == 32 || byte == 9 || byte == 10 || byte == 13
            if !space || !previousSpace { bytes.append(space ? 32 : byte) }
            previousSpace = space
        }
        return String(decoding: bytes, as: UTF8.self)
    }
    static func unavailableImageText(_ node: MarkdownNode) -> String {
        node.text.isEmpty ? "Image indisponible" : "Image indisponible : \(inlineText(node.text))"
    }

    /// Texte canonique : espaces inline regroupés, code conservé, deux LF entre blocs.
    /// Les mêmes chaînes servent à l’émetteur ; les images raster affichées n’ajoutent pas leur alt.
    static func project(_ root: MarkdownNode, loadedImages: Set<Int> = []) -> VisibleTextProjection {
        projectWithNodes(root, loadedImages: loadedImages).projection
    }

    static func projectWithNodes(_ root: MarkdownNode, loadedImages: Set<Int> = []) -> (projection: VisibleTextProjection, values: [Int: String]) {
        var values: [Int: String] = [:]
        var previousTextSpace = false
        var text = ""
        var offset = 0
        var runs: [VisibleTextRun] = []
        var boundaries: [Int] = []
        func separate() {
            guard !text.isEmpty else { return }
            if !text.hasSuffix("\n\n") {
                let separator = text.hasSuffix("\n") ? "\n" : "\n\n"
                text += separator; offset += separator.utf16.count
            }
            boundaries.append(offset)
            previousTextSpace = false
        }
        func visit(_ node: MarkdownNode) {
            var value: String?
            switch node.kind {
            case .image: value = loadedImages.contains(node.id) ? nil : unavailableImageText(node)
            case .text: value = inlineText(node.text)
            case .inlineCode, .codeBlock, .rawHTMLLiteral, .softBreak, .hardBreak: value = node.text
            default: value = nil
            }
            switch node.kind {
            case .text, .softBreak:
                if previousTextSpace, let raw = value, raw.hasPrefix(" ") { value = String(raw.dropFirst()) }
                if let value, !value.isEmpty { previousTextSpace = value.hasSuffix(" ") }
            case .inlineCode, .codeBlock, .rawHTMLLiteral, .image, .hardBreak: previousTextSpace = false
            default: break
            }
            if let value { values[node.id] = value }
            if let value, !value.isEmpty {
                let start = offset
                let length = value.utf16.count
                text += value; offset += length
                runs.append(VisibleTextRun(nodeID: node.id, visibleUTF16Range: start..<offset, nodeUTF16Range: 0..<length))
            } else if case .image = node.kind {
                // Le texte alternatif est représenté par l’image ou son remplacement, pas deux fois.
            } else {
                node.children.forEach(visit)
            }
            switch node.kind {
            case .paragraph, .heading, .codeBlock, .listItem, .blockQuote, .tableRow, .thematicBreak: separate()
            case .tableCell: text += "\t"; offset += 1; previousTextSpace = false
            default: break
            }
        }
        visit(root)
        return (VisibleTextProjection(text: text, runs: runs, blockBoundaries: boundaries), values)
    }
}
