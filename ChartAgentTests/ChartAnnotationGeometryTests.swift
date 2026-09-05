import XCTest
@testable import ChartAgent

final class ChartAnnotationGeometryTests: XCTestCase {
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
                                      labelAnchor: .init(x: 0.5, y: 0.1))
        let parallel = try XCTUnwrap(channel.parallelBoundary)
        let rect = ChartAnnotationGeometry.imageRect(imageSize: CGSize(width: 2266, height: 1312),
                                                     container: CGSize(width: 360, height: 300))
        let a = channel.points[0].position(in: rect), b = channel.points[1].position(in: rect)
        let c = parallel[0].position(in: rect), d = parallel[1].position(in: rect)
        XCTAssertEqual((b.y - a.y) / (b.x - a.x), (d.y - c.y) / (d.x - c.x), accuracy: 0.000001)
        XCTAssertEqual(a.y - c.y, b.y - d.y, accuracy: 0.000001)
    }
}
