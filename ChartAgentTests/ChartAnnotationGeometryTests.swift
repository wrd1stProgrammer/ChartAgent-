import XCTest
@testable import ChartAgent

final class ChartAnnotationGeometryTests: XCTestCase {
    func testTrendExtensionKeepsThePivotSlopeAndRejectsOffImageEndpoints() throws {
        let line = ChartAnnotation(id: "trend", kind: .line, title: "상승 추세선", detail: "두 저점 연결",
                                   outlook: "연장선 지지 여부를 확인합니다.", scenarioIndex: nil, tone: .mint,
                                   points: [.init(x: 0.2, y: 0.7), .init(x: 0.5, y: 0.5)],
                                   labelAnchor: .init(x: 0.3, y: 0.8), extendToX: 0.8)
        let extended = try XCTUnwrap(line.trendExtension)
        XCTAssertEqual(extended[0], line.points[1])
        XCTAssertEqual(extended[1].x, 0.8, accuracy: 0.000001)
        XCTAssertEqual(extended[1].y, 0.3, accuracy: 0.000001)
        let invalid = ChartAnnotation(id: "trend", kind: .line, title: "상승 추세선", detail: "두 저점 연결",
                                      outlook: "연장선 지지 여부를 확인합니다.", scenarioIndex: nil, tone: .mint,
                                      points: [.init(x: 0.2, y: 0.7), .init(x: 0.5, y: 0.2)],
                                      labelAnchor: .init(x: 0.3, y: 0.8), extendToX: 0.9)
        XCTAssertNil(invalid.trendExtension)
    }

    func testCoordinatesFollowAspectFitInsteadOfContainerBounds() {
        let rect = ChartAnnotationGeometry.imageRect(imageSize: CGSize(width: 1600, height: 900),
                                                     container: CGSize(width: 360, height: 360))
        let point = ChartImagePoint(x: 0.75, y: 0.25).position(in: rect)
        XCTAssertEqual(point.x, 270, accuracy: 0.01)
        XCTAssertEqual(point.y, 129.375, accuracy: 0.01)
    }

    func testOverlappingLabelsStaySeparatedAndInsideImage() {
        let rect = CGRect(x: 0, y: 40, width: 350, height: 280)
        let frames = ChartAnnotationGeometry.labelFrames(
            anchors: [CGPoint(x: 340, y: 60), CGPoint(x: 335, y: 65), CGPoint(x: 330, y: 70)],
            imageRect: rect, labelSizes: Array(repeating: CGSize(width: 100, height: 18), count: 3)
        )
        XCTAssertTrue(frames.allSatisfy(rect.contains))
        XCTAssertFalse(frames[0].intersects(frames[1]))
        XCTAssertFalse(frames[1].intersects(frames[2]))
    }

    func testCaptionMovesAwayFromMarkedEvidence() {
        let rect = CGRect(x: 0, y: 0, width: 350, height: 280)
        let evidence = CGRect(x: 120, y: 125, width: 110, height: 20)
        let frames = ChartAnnotationGeometry.labelFrames(
            anchors: [CGPoint(x: 175, y: 135)], imageRect: rect,
            labelSizes: [CGSize(width: 100, height: 18)], avoiding: [evidence]
        )
        XCTAssertFalse(frames[0].intersects(evidence))
        XCTAssertTrue(rect.contains(frames[0]))
    }

    func testChannelUsesOneSlopeForBothBoundariesAfterAspectFit() throws {
        let channel = ChartAnnotation(id: "channel", kind: .channel, title: "하락 채널",
                                      detail: "반복되는 고점과 저점", outlook: "상단 돌파 전까지 하락 구조가 유지됩니다.",
                                      scenarioIndex: nil, tone: .blue,
                                      points: [.init(x: 0.2, y: 0.3), .init(x: 0.8, y: 0.6), .init(x: 0.5, y: 0.2)],
                                      labelAnchor: .init(x: 0.5, y: 0.1), extendToX: nil)
        let parallel = try XCTUnwrap(channel.parallelBoundary)
        let rect = ChartAnnotationGeometry.imageRect(imageSize: CGSize(width: 2266, height: 1312),
                                                     container: CGSize(width: 360, height: 300))
        let a = channel.points[0].position(in: rect), b = channel.points[1].position(in: rect)
        let c = parallel[0].position(in: rect), d = parallel[1].position(in: rect)
        XCTAssertEqual((b.y - a.y) / (b.x - a.x), (d.y - c.y) / (d.x - c.x), accuracy: 0.000001)
        XCTAssertEqual(a.y - c.y, b.y - d.y, accuracy: 0.000001)
    }
}

final class ChartAnnotationLoadingTests: XCTestCase {
    @MainActor
    func testPrefetchAndResultShareOneRequestAndCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let started = expectation(description: "Annotation request started before result presentation")
        var continuation: CheckedContinuation<ChartAnnotationDocument, Never>?
        var calls = 0
        let store = AnalysisStore(storageDirectory: directory) { _, _, _ in
            calls += 1
            return await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let prefetch = store.prepareChartAnnotations(analysisID: "test", imageData: Data(), analysis: analysis, locale: "ko")
        await fulfillment(of: [started], timeout: 1)
        let result = store.prepareChartAnnotations(analysisID: "test", imageData: Data(), analysis: analysis, locale: "ko")
        continuation?.resume(returning: document)
        let prefetched = try await prefetch.value
        let displayed = try await result.value
        let cached = try await store.prepareChartAnnotations(analysisID: "test", imageData: Data(), analysis: analysis, locale: "ko").value
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(prefetched, displayed)
        XCTAssertEqual(cached, displayed)
    }

    @MainActor
    func testFailedPrefetchRetriesOnlyWhenRequested() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ready = document
        var calls = 0
        let store = AnalysisStore(storageDirectory: directory) { _, _, _ in
            calls += 1
            if calls == 1 { throw ChartAgentAPIError.invalidResponse }
            return ready
        }
        for _ in 0..<2 {
            do {
                _ = try await store.prepareChartAnnotations(analysisID: "test", imageData: Data(), analysis: analysis, locale: "ko").value
                XCTFail("The failed request should remain available to the result screen")
            } catch {
                XCTAssertEqual(error as? ChartAgentAPIError, .invalidResponse)
            }
        }
        XCTAssertEqual(calls, 1)
        let retried = try await store.prepareChartAnnotations(analysisID: "test", imageData: Data(), analysis: analysis, locale: "ko", retry: true).value
        XCTAssertEqual(retried, ready)
        XCTAssertEqual(calls, 2)
    }

    private var document: ChartAnnotationDocument {
        .init(locale: "ko", imageWidth: 640, imageHeight: 480, summary: "판독 가능한 경계를 확인합니다.", annotations: [])
    }

    private var analysis: AnalysisPayload {
        .init(validation: .init(isChart: true, isReadable: true, detectedSymbol: "TEST", detectedTimeframe: "4H",
                                reasonCode: "ok", message: "차트입니다."),
              consensus: .init(title: "관찰", stanceCode: "observe", confidence: 60, summary: "확인 대기"),
              scope: .init(visible: ["캔들"], unavailable: []), agentOpinions: [], scenarios: [], structure: [],
              meetingScript: [], dataQuality: .init(chart: "good", priceAxis: "good", timeframe: "good", news: "unused"),
              newsImpact: nil, tradePlan: nil, followUpSuggestions: [])
    }
}
