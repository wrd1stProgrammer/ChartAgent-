import SwiftUI

struct CandlestickChart: View {
    var showTradeLevels = true
    var accent = ChartTheme.mint

    private let candles: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.62, 0.52, 0.68, 0.45), (0.53, 0.59, 0.66, 0.48),
        (0.59, 0.68, 0.72, 0.54), (0.68, 0.79, 0.84, 0.64),
        (0.78, 0.72, 0.82, 0.66), (0.73, 0.84, 0.88, 0.69),
        (0.84, 0.89, 0.94, 0.80), (0.88, 0.76, 0.92, 0.71),
        (0.76, 0.65, 0.80, 0.60), (0.64, 0.58, 0.69, 0.52),
        (0.58, 0.49, 0.63, 0.44), (0.49, 0.42, 0.55, 0.38),
        (0.42, 0.47, 0.51, 0.36), (0.47, 0.40, 0.51, 0.35),
        (0.40, 0.33, 0.44, 0.28), (0.33, 0.38, 0.42, 0.29),
        (0.38, 0.31, 0.42, 0.27), (0.31, 0.25, 0.35, 0.20)
    ]

    var body: some View {
        Canvas { context, size in
            drawGrid(in: &context, size: size)
            drawCandles(in: &context, size: size)
            if showTradeLevels { drawLevels(in: &context, size: size) }
        }
        .accessibilityLabel("온보딩 예시 캔들 차트")
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        for index in 1..<5 {
            let y = size.height * CGFloat(index) / 5
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 1)
        }
        for index in 1..<6 {
            let x = size.width * CGFloat(index) / 6
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
        }
    }

    private func drawCandles(in context: inout GraphicsContext, size: CGSize) {
        let step = size.width / CGFloat(candles.count + 1)
        let bodyWidth = max(5, step * 0.56)

        for (index, candle) in candles.enumerated() {
            let x = step * CGFloat(index + 1)
            let rising = candle.1 < candle.0
            let color = rising ? accent : ChartTheme.coral
            let highY = candle.2 * size.height
            let lowY = candle.3 * size.height
            var wick = Path()
            wick.move(to: CGPoint(x: x, y: highY))
            wick.addLine(to: CGPoint(x: x, y: lowY))
            context.stroke(wick, with: .color(color), lineWidth: 1.4)

            let openY = candle.0 * size.height
            let closeY = candle.1 * size.height
            let body = CGRect(
                x: x - bodyWidth / 2,
                y: min(openY, closeY),
                width: bodyWidth,
                height: max(4, abs(closeY - openY))
            )
            context.fill(Path(roundedRect: body, cornerRadius: 1.5), with: .color(color))
        }
    }

    private func drawLevels(in context: inout GraphicsContext, size: CGSize) {
        for (ratio, color) in [(0.22, accent), (0.48, Color.white), (0.77, ChartTheme.coral)] {
            let y = size.height * ratio
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(color.opacity(0.72)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }
}
