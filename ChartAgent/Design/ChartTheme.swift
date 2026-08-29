import SwiftUI

enum ChartTheme {
    static let background = Color(red: 0.012, green: 0.027, blue: 0.031)
    static let surface = Color(red: 0.045, green: 0.059, blue: 0.071)
    static let surfaceRaised = Color(red: 0.071, green: 0.086, blue: 0.102)
    static let stroke = Color.white.opacity(0.10)
    static let mint = Color(red: 0.18, green: 0.96, blue: 0.70)
    static let mintDeep = Color(red: 0.035, green: 0.25, blue: 0.20)
    static let coral = Color(red: 1.0, green: 0.31, blue: 0.43)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.26)
    static let violet = Color(red: 0.60, green: 0.55, blue: 1.0)
    static let blue = Color(red: 0.35, green: 0.58, blue: 1.0)
    static let secondaryText = Color.white.opacity(0.57)

    static let screenPadding: CGFloat = 20
    static let corner: CGFloat = 22
}

extension View {
    func chartCard(
        fill: Color = ChartTheme.surface,
        stroke: Color = ChartTheme.stroke,
        radius: CGFloat = ChartTheme.corner
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            ChartTheme.background
            RadialGradient(
                colors: [ChartTheme.mint.opacity(0.11), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct InvestmentDisclaimerView: View {
    var body: some View {
        Text("AI 분석 결과는 교육 및 참고용이며 투자 권유가 아닙니다.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.38))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: .infinity)
    }
}
