import Foundation
import CoreGraphics

struct ChartImagePoint: Codable, Equatable {
    let x: Double
    let y: Double

    var isNormalized: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }

    func position(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
}

struct ChartAnnotation: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case line, zone, arrow, channel }
    enum Tone: String, Codable { case mint, coral, amber, blue }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let outlook: String
    let scenarioIndex: Int?
    let tone: Tone
    let points: [ChartImagePoint]
    let labelAnchor: ChartImagePoint
    let extendToX: Double?

    var trendExtension: [ChartImagePoint]? {
        guard let extendToX, extendToX.isFinite, kind == .line, points.count == 2 else { return nil }
        let start = points[0], end = points[1]
        guard end.x - start.x >= 0.04, extendToX > end.x, extendToX <= 1 else { return nil }
        let slope = (end.y - start.y) / (end.x - start.x)
        let extended = ChartImagePoint(x: extendToX, y: end.y + slope * (extendToX - end.x))
        return extended.isNormalized ? [end, extended] : nil
    }

    var parallelBoundary: [ChartImagePoint]? {
        guard kind == .channel, points.count == 3 else { return nil }
        let start = points[0], end = points[1], opposite = points[2]
        guard end.x - start.x >= 0.04, (start.x...end.x).contains(opposite.x) else { return nil }
        let slope = (end.y - start.y) / (end.x - start.x)
        let offset = opposite.y - (start.y + slope * (opposite.x - start.x))
        let boundary = [ChartImagePoint(x: start.x, y: start.y + offset),
                        ChartImagePoint(x: end.x, y: end.y + offset)]
        guard abs(offset) >= 0.01, boundary.allSatisfy(\.isNormalized) else { return nil }
        return boundary
    }
}

struct ChartAnnotationDocument: Codable, Equatable {
    let locale: String
    let imageWidth: Int
    let imageHeight: Int
    let summary: String
    let annotations: [ChartAnnotation]

    var isValid: Bool {
        !locale.isEmpty && imageWidth > 0 && imageHeight > 0 && annotations.count <= 3
            && Set(annotations.map(\.id)).count == annotations.count
            && annotations.allSatisfy { item in
                (2...6).contains(item.points.count)
                    && (item.kind == .line || (item.kind == .channel ? item.parallelBoundary != nil : item.points.count == 2))
                    && item.points.allSatisfy(\.isNormalized)
                    && item.labelAnchor.isNormalized
                    && (item.extendToX == nil || item.trendExtension != nil)
                    && !item.title.isEmpty && item.title.count <= 24
                    && !item.outlook.isEmpty
            }
    }

    static func cacheKey(analysisID: String, locale: String) -> String {
        analysisID + ":" + locale + ":api2:v4"
    }

    func hasValidScenarioLinks(count: Int) -> Bool {
        annotations.allSatisfy { item in
            guard let index = item.scenarioIndex else { return true }
            return (0..<count).contains(index)
        }
    }
}

struct ChartAnnotationContext: Encodable {
    let consensus: ConsensusResult
    let scenarios: [AnalysisScenario]
    let structure: [StructureLevel]
    let trendEvidence: [String]
    let trigger: String?
    let invalidation: String?
    let target: String?

    init(analysis: AnalysisPayload) {
        consensus = analysis.consensus
        scenarios = analysis.scenarios
        structure = analysis.structure
        let trend = analysis.agentOpinions.first { $0.agentId == "trend" }
        trendEvidence = Array(([trend?.thesis].compactMap { $0 } + (trend?.evidence ?? [])).prefix(6))
        trigger = analysis.tradePlan?.trigger
        invalidation = analysis.tradePlan?.stop
        target = analysis.tradePlan?.target
    }
}

enum ChartAnnotationGeometry {
    static func imageRect(imageSize: CGSize, container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }

    static func labelFrames(anchors: [CGPoint], imageRect: CGRect, labelSizes: [CGSize],
                            avoiding obstacles: [CGRect] = []) -> [CGRect] {
        let available = imageRect.insetBy(dx: 6, dy: 6)
        var placed: [CGRect] = []
        for (index, anchor) in anchors.enumerated() {
            let labelSize = labelSizes[index]
            let offsets: [CGFloat] = [0, -0.25, 0.25, -0.5, 0.5, -0.75, 0.75, -1, 1, -2, 2, -3, 3]
            let horizontalOffsets: [CGFloat] = [0, -0.5, 0.5, -1, 1]
            var candidates: [CGRect] = []
            for vertical in offsets {
                for horizontal in horizontalOffsets {
                    let proposedX = anchor.x - labelSize.width / 2 + horizontal * labelSize.width
                    let proposedY = anchor.y - labelSize.height / 2 + vertical * (labelSize.height + 8)
                    let x = min(max(proposedX, available.minX), available.maxX - labelSize.width)
                    let y = min(max(proposedY, available.minY), available.maxY - labelSize.height)
                    candidates.append(CGRect(origin: CGPoint(x: x, y: y), size: labelSize))
                }
            }
            let separated = candidates.filter { candidate in
                placed.allSatisfy { !$0.insetBy(dx: -3, dy: -3).intersects(candidate) }
            }
            let frame = separated.first { candidate in
                obstacles.allSatisfy { !$0.intersects(candidate) }
            } ?? separated.first ?? candidates[0]
            placed.append(frame)
        }
        return placed
    }

    static func markObstacles(_ annotations: [ChartAnnotation], in rect: CGRect) -> [CGRect] {
        annotations.flatMap { item in
            let points = item.points.map { $0.position(in: rect) }
            if item.kind == .zone, let first = points.first, let last = points.last {
                return [CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                               width: abs(last.x - first.x), height: abs(last.y - first.y)).insetBy(dx: -6, dy: -6)]
            }
            let paths: [[CGPoint]]
            if let boundary = item.parallelBoundary {
                paths = [Array(points.prefix(2)), boundary.map { $0.position(in: rect) }]
            } else {
                paths = [points] + (item.trendExtension.map { [$0.map { $0.position(in: rect) }] } ?? [])
            }
            return paths.flatMap { path in zip(path, path.dropFirst()).flatMap { start, end in
                let steps = max(1, Int(hypot(end.x - start.x, end.y - start.y) / 6))
                return (0...steps).map { step in
                    let fraction = CGFloat(step) / CGFloat(steps)
                    return CGRect(x: start.x + (end.x - start.x) * fraction - 6,
                                  y: start.y + (end.y - start.y) * fraction - 6, width: 12, height: 12)
                }
            } }
        }
    }
}
