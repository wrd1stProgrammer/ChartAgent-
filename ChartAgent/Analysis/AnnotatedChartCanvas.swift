import SwiftUI
import UIKit

enum ChartAnnotationStyle {
    static let stroke: CGFloat = 1.25
    static let labelCorner: CGFloat = 3

    static func labelFontSize(expanded: Bool) -> CGFloat { expanded ? 10.5 : 9 }

    static func labelSize(title: String, index: Int, expanded: Bool, availableWidth: CGFloat) -> CGSize {
        let font = UIFont.systemFont(ofSize: labelFontSize(expanded: expanded), weight: .semibold)
        let text = "\(index + 1) · \(title)" as NSString
        let width = text.size(withAttributes: [.font: font]).width + 6
        return CGSize(width: min(ceil(width), min(availableWidth - 12, expanded ? 170 : 132)),
                      height: ceil(font.lineHeight) + 4)
    }

    static func color(_ tone: ChartAnnotation.Tone) -> Color {
        switch tone {
        case .mint: ChartTheme.mint
        case .coral: ChartTheme.coral
        case .amber: ChartTheme.amber
        case .blue: ChartTheme.blue
        }
    }
}

struct AnnotatedChartCanvas: View {
    let image: UIImage
    let annotations: [ChartAnnotation]
    @Binding var selectedID: String?
    var expanded = false

    var body: some View {
        GeometryReader { geometry in
            let rect = ChartAnnotationGeometry.imageRect(imageSize: image.size, container: geometry.size)
            let labelSizes = annotations.enumerated().map { index, item in
                ChartAnnotationStyle.labelSize(title: item.title, index: index, expanded: expanded, availableWidth: rect.width)
            }
            let labels = ChartAnnotationGeometry.labelFrames(
                anchors: annotations.map { $0.labelAnchor.position(in: rect) }, imageRect: rect, labelSizes: labelSizes,
                avoiding: ChartAnnotationGeometry.markObstacles(annotations, in: rect)
            )
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityLabel("업로드한 차트")

                Canvas { context, _ in
                    for (index, item) in annotations.enumerated() {
                        draw(item, in: rect, label: labels[index], context: &context)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(annotations) { item in
                    if let index = annotations.firstIndex(where: { $0.id == item.id }) {
                        let frame = labels[index]
                        Button { selectedID = item.id } label: {
                            Text(verbatim: "\(index + 1) · \(item.title)")
                            .font(.system(size: ChartAnnotationStyle.labelFontSize(expanded: expanded), weight: .semibold))
                            .foregroundStyle(ChartAnnotationStyle.color(item.tone))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 3)
                            .frame(width: frame.width, height: frame.height)
                            .background(ChartTheme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: ChartAnnotationStyle.labelCorner))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: frame.midX, y: frame.midY)
                        .accessibilityLabel("\(index + 1). \(item.title). \(item.detail)")
                        .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
                    }
                }
            }
        }
        .clipped()
    }

    private func draw(_ item: ChartAnnotation, in rect: CGRect, label: CGRect, context: inout GraphicsContext) {
        let points = item.points.map { $0.position(in: rect) }
        guard let first = points.first, let last = points.last else { return }
        let color = ChartAnnotationStyle.color(item.tone)
        var path = Path()
        switch item.kind {
        case .channel:
            guard let boundary = item.parallelBoundary else { return }
            let opposite = boundary.map { $0.position(in: rect) }
            path.move(to: points[0])
            path.addLine(to: points[1])
            path.move(to: opposite[0])
            path.addLine(to: opposite[1])
            var area = Path()
            area.move(to: points[0])
            area.addLine(to: points[1])
            area.addLine(to: opposite[1])
            area.addLine(to: opposite[0])
            area.closeSubpath()
            context.fill(area, with: .color(color.opacity(0.035)))
        case .line, .arrow:
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            if item.kind == .arrow {
                let angle = atan2(last.y - first.y, last.x - first.x)
                for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                    path.move(to: CGPoint(x: last.x - 9 * cos(angle + offset), y: last.y - 9 * sin(angle + offset)))
                    path.addLine(to: last)
                }
            }
        case .zone:
            let zone = CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                              width: abs(last.x - first.x), height: abs(last.y - first.y))
            path.addRect(zone)
            context.fill(path, with: .color(color.opacity(0.10)))
        }
        let width = ChartAnnotationStyle.stroke + (selectedID == item.id ? 0.25 : 0)
        context.stroke(path, with: .color(ChartTheme.background.opacity(0.35)), lineWidth: width + 1)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round,
                                                                 lineJoin: .round, dash: item.kind == .zone ? [4, 3] : []))
        if let extensionPoints = item.trendExtension {
            var extensionPath = Path()
            extensionPath.move(to: extensionPoints[0].position(in: rect))
            extensionPath.addLine(to: extensionPoints[1].position(in: rect))
            context.stroke(extensionPath, with: .color(color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [4, 3]))
        }
        let target = item.kind == .zone ? CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
            : item.trendExtension?.last?.position(in: rect) ?? last
        let edge = CGPoint(x: min(max(target.x, label.minX), label.maxX), y: min(max(target.y, label.minY), label.maxY))
        var leader = Path()
        leader.move(to: edge)
        leader.addLine(to: target)
        context.stroke(leader, with: .color(ChartTheme.background.opacity(0.25)), lineWidth: 1.5)
        context.stroke(leader, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        context.fill(Path(ellipseIn: CGRect(x: target.x - 2, y: target.y - 2, width: 4, height: 4)), with: .color(color))
    }
}
