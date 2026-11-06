import Foundation

struct SearchMarkup {
    private let segments: [Int: [SearchSegment]]
    private let current: Int?
    init(_ state: SearchState?) {
        segments = Dictionary(grouping: state?.matches.flatMap(\.segments) ?? [], by: \.nodeID)
        current = state?.currentIndex
    }
    func emit(_ text: String, nodeID: Int) -> String {
        guard let marks = segments[nodeID] else { return SafeHTMLRenderer.escape(text) }
        let ns = text as NSString
        var cursor = 0, output = ""
        for mark in marks.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            guard mark.range.lowerBound >= cursor, mark.range.upperBound <= ns.length else { continue }
            output += SafeHTMLRenderer.escape(ns.substring(with: NSRange(location: cursor, length: mark.range.lowerBound - cursor)))
            let anchor = mark.isFirst ? " id=\"search-\(mark.occurrence)\"" : ""
            let active = mark.occurrence == current ? " class=\"current-result\"" : ""
            output += "<mark\(anchor)\(active)>\(SafeHTMLRenderer.escape(ns.substring(with: NSRange(mark.range))))</mark>"
            cursor = mark.range.upperBound
        }
        output += SafeHTMLRenderer.escape(ns.substring(from: cursor))
        return output
    }
}
