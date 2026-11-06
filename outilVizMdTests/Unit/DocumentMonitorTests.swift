import XCTest
@testable import outilVizMd

final class DocumentMonitorTests: XCTestCase {
    func testDebounceUsesLatestEventAndStopsAfterClose() {
        var refresh = RefreshController()
        let id = UUID()
        refresh.signal(id, at: 1_000)
        XCTAssertFalse(refresh.isDue(id, at: 1_149))
        refresh.signal(id, at: 1_100)
        XCTAssertFalse(refresh.isDue(id, at: 1_200))
        XCTAssertTrue(refresh.isDue(id, at: 1_250))
        refresh.remove(id)
        XCTAssertFalse(refresh.isDue(id, at: 9_999))
    }
}
