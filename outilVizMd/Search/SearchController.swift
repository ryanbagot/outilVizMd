import Foundation

actor SearchController {
    private let indexer = SearchIndexer()
    func search(_ query: String, projection: VisibleTextProjection, documentID: UUID, sourceGeneration: UInt64, queryGeneration: UInt64) async -> SearchState {
        let matches = await indexer.find(query, in: VisibleTextIndex(projection))
        return SearchState(documentID: documentID, sourceGeneration: sourceGeneration, queryGeneration: queryGeneration, query: query, matches: matches, currentIndex: 0)
    }
}
