import Foundation

actor SearchIndexer {
    func find(_ query: String, in index: VisibleTextIndex) -> [SearchMatch] { Self.matches(query, in: index) }

    nonisolated static func matches(_ query: String, in index: VisibleTextIndex) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        let text = index.projection.text
        let ns = text as NSString
        var cursor = 0
        var results: [SearchMatch] = []
        var runCursor = 0
        let runs = index.projection.runs
        while cursor < ns.length {
            if Task.isCancelled { return [] }
            let found = ns.range(of: query, options: [.caseInsensitive], range: NSRange(location: cursor, length: ns.length - cursor))
            guard found.location != NSNotFound, found.length > 0 else { break }
            cursor = found.location + found.length
            guard ns.rangeOfComposedCharacterSequences(for: found) == found else { continue }
            let range = found.location..<cursor
            var segments: [SearchSegment] = []
            while runCursor < runs.count && runs[runCursor].visibleUTF16Range.upperBound <= range.lowerBound { runCursor += 1 }
            var runIndex = runCursor
            while runIndex < runs.count && runs[runIndex].visibleUTF16Range.lowerBound < range.upperBound {
                let run = runs[runIndex]
                runIndex += 1
                let lower = max(range.lowerBound, run.visibleUTF16Range.lowerBound)
                let upper = min(range.upperBound, run.visibleUTF16Range.upperBound)
                guard lower < upper else { continue }
                let start = run.nodeUTF16Range.lowerBound + lower - run.visibleUTF16Range.lowerBound
                segments.append(SearchSegment(nodeID: run.nodeID, range: start..<(start + upper - lower), occurrence: results.count, isFirst: segments.isEmpty))
            }
            // Une requête ne correspondant qu’aux séparateurs n’a pas de résultat visible.
            if !segments.isEmpty { results.append(SearchMatch(range: range, segments: segments)) }
        }
        return results
    }
}
