import XCTest
@testable import NavigationWatchCore

final class Phase107PipelineTests: XCTestCase {
    let date = Date(timeIntervalSince1970: 10_000)
    func flowing(at tick: Double = 20) -> NavigationPipelineMeasurements {
        var m = NavigationPipelineMeasurements()
        m.startedTick = 0; m.navigationActive = true; m.routeActive = true; m.observerActive = true
        m.sessionID = UUID(); m.sequence = 8; m.providerStarts = 1
        m.coreConsumedSession = m.sessionID; m.coreConsumedSequence = 8
        for layer in PipelineLayer.allCases { m.observe(layer, tick: tick, date: date) }
        m.sourceAgeAtCallback = 0; m.coreSourceAgeAtCallback = 0; m.coreAccuracy = 5
        return m
    }
    func testNormalPipeline() {
        XCTAssertEqual(flowing().classify(at: 21, freshness: .fresh), .none)
        // No new upstream input means no outstanding snapshot generation work.
        var m = flowing(at: 0.8); m.startedTick = 0
        m.checkpoints[.providerNavigation]?.tick = 0.7
        m.sourceAgeAtCallback = 1
        m.coreConsumedSession = m.sessionID; m.coreConsumedSequence = m.sequence
        XCTAssertEqual(m.classify(at: 5.4, freshness: .delayed), .unknown)
    }
    func testCoreLocationStall() {
        var m = flowing(); m.checkpoints[.coreLocation]?.tick = 0
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .coreLocationStalled)
        m.observerActive = false
        XCTAssertEqual(m.classify(at: 21, freshness: .fresh), .none)
    }
    func testAMapRawLocationStallWhileNavigationKeepsFlowing() {
        var m = flowing(); m.checkpoints[.amapLocation]?.tick = 0
        XCTAssertEqual(m.classify(at: 44, freshness: .stale), .coreLocationStalled)
        m.observe(.coreLocation, tick: 44, date: date)
        m.observe(.amapNavigation, tick: 44, date: date)
        m.observe(.providerNavigation, tick: 44, date: date)
        m.observe(.snapshot, tick: 44, date: date)
        m.observe(.providerSnapshot, tick: 44, date: date)
        m.observe(.coreConsumed, tick: 44, date: date)
        XCTAssertEqual(m.classify(at: 44, freshness: .stale), .amapRawCallbackStalled)
        m.coreSourceAgeAtCallback = 40
        XCTAssertEqual(m.classify(at: 44, freshness: .stale), .unknown)
    }
    func testRawCallbackBeforeActorHopDetectsMissingForward() {
        var m = flowing(); m.checkpoints[.providerLocation]?.tick = 0
        m.observe(.amapLocation, tick: 21, date: date)
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .providerForwardingStalled)
        m = flowing(); m.checkpoints[.providerSnapshot]?.tick = 0
        m.observe(.snapshot, tick: 21, date: date)
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .providerForwardingStalled)
        m = flowing(); m.checkpoints[.providerNavigation]?.tick = 0
        m.observe(.amapNavigation, tick: 21, date: date); m.rawNavigationHasData = false
        XCTAssertEqual(m.classify(at: 21, freshness: .fresh), .none)
    }
    func testProviderNormalSnapshotNotGenerated() {
        var m = flowing(); m.checkpoints[.snapshot]?.tick = 0
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .snapshotGenerationStalled)
        m = flowing(); m.checkpoints[.coreConsumed]?.tick = 0; m.coreConsumedSequence = 7
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .coreConsumptionStalled)
    }
    func testFreshnessMismatchAndOldSourceIsNotFalseMismatch() {
        var m = flowing()
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .freshnessClassificationMismatch)
        m.sourceAgeAtCallback = 40
        XCTAssertEqual(m.classify(at: 21, freshness: .stale), .unknown)
    }
    func testMissingEvidenceAndStoppedNavigationRemainUnknown() {
        var m = NavigationPipelineMeasurements()
        XCTAssertEqual(m.classify(at: 50, freshness: .stale), .unknown)
        m = flowing(); m.navigationActive = false
        XCTAssertEqual(m.classify(at: 50, freshness: .stale), .unknown)
    }
    func report(_ m: inout NavigationPipelineMeasurements, tick: Double, freshness: NavigationFreshness) -> (String?, NavigationPipelineDiagnosticSnapshot) {
        m.diagnostic(at: tick, date: date.addingTimeInterval(-500), freshness: freshness,
            lifecycle: "active", authorization: "whenInUse", watchConnectivity: "activated/true", gps: "strong")
    }
    func testTransitionsAndNaturalRecoveryUseMonotonicTimeAndSameSession() throws {
        var m = flowing()
        XCTAssertNil(report(&m, tick: 20, freshness: .fresh).0)
        XCTAssertEqual(report(&m, tick: 26, freshness: .delayed).0, "pipeline_stall_snapshot")
        XCTAssertNil(report(&m, tick: 27, freshness: .delayed).0)
        XCTAssertEqual(report(&m, tick: 36, freshness: .stale).0, "pipeline_stall_snapshot")
        m.observe(.amapLocation, tick: 40, date: date.addingTimeInterval(-1000))
        m.sequence = 9
        let result = report(&m, tick: 41, freshness: .fresh)
        XCTAssertEqual(result.0, "pipeline_recovered")
        XCTAssertEqual(result.1.staleDuration, 5)
        XCTAssertEqual(result.1.sameSession, true); XCTAssertEqual(result.1.sequenceContinued, true)
        XCTAssertEqual(result.1.sessionRebuilt, false); XCTAssertEqual(result.1.firstRecoveredLayer, "amapLocation")
        XCTAssertNil(report(&m, tick: 42, freshness: .fresh).0)
        let data = try JSONEncoder().encode(result.1)
        XCTAssertEqual(try JSONDecoder().decode(NavigationPipelineDiagnosticSnapshot.self, from: data).sequence, 9)
    }
    func testNewSessionNotMisreportedAsNaturalSameSessionRecovery() {
        var m = flowing(); _ = report(&m, tick: 36, freshness: .stale)
        m.sessionID = UUID(); m.sequence = 1; m.providerStarts = 2
        let result = report(&m, tick: 40, freshness: .fresh).1
        XCTAssertEqual(result.sameSession, false); XCTAssertEqual(result.sequenceContinued, false); XCTAssertEqual(result.sessionRebuilt, true)
    }
    func testRecorderRejectsOldProviderCallbacksAndCountsBeforeAsyncConsumption() {
        let r = NavigationPipelineRecorder(); let owner = UUID()
        r.begin(owner: owner, session: UUID())
        r.observe(.amapLocation, owner: UUID(), source: date)
        r.update(owner: UUID()) { $0.routeActive = false }
        r.observe(.amapLocation, owner: owner, source: Date())
        let row = r.diagnostic(freshness: .fresh, lifecycle: "active", authorization: "whenInUse", watchConnectivity: "unknown", gps: "unknown").1
        XCTAssertEqual(row.checkpoints["amapLocation"]?.count, 1)
        XCTAssertNil(row.checkpoints["providerLocation"])
        XCTAssertTrue(row.routeActive)
    }
}
