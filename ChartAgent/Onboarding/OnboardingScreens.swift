import SwiftUI

struct HeroOnboarding: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingOfficePreview()

            VStack(spacing: 10) {
                Text("혼자 추측하지 말고.")
                    .font(.system(size: 32, weight: .black))
                Text("팀으로 분석하세요.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(ChartTheme.mint)
                Text("다섯 에이전트가 각자 읽고, 서로 반박한 뒤\n실행 가능한 조건만 한 리포트로 남깁니다.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ChartTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
    }
}

private struct OnboardingOfficePreview: View {
    private var dialogues: [String] {
        PixelAgent.team.map(\.localizedMessage)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3.4)) { context in
            let speaker = Int(context.date.timeIntervalSinceReferenceDate / 3.4) % PixelAgent.team.count
            PixelOfficeView(
                focusedAgentIndex: speaker,
                bubbleText: dialogues[speaker],
                mode: .office,
                isAnalyzing: true,
                showsMeetingTable: true,
                height: 382,
                bubbleTypingBudget: 1.15
            )
        }
    }
}

struct HowItWorksOnboarding: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "How it works",
                title: "네 번의 탭으로\n분석과 후속 질문까지.",
                subtitle: "차트를 올리고, 회의를 지켜본 뒤 필요한 근거를 바로 더 물어보세요."
            )
            VStack(spacing: 10) {
                FeatureRow(number: "1", icon: "camera.viewfinder", title: "차트 캡처", subtitle: "이미지 한 장만 올리면 돼요")
                FeatureRow(number: "2", icon: "person.3.sequence.fill", title: "에이전트 회의", subtitle: "다섯 관점이 독립 분석하고 반론해요")
                FeatureRow(number: "3", icon: "checkmark.shield.fill", title: "판단 리포트", subtitle: "확인·무효화·반대 조건까지 정리해요")
                FeatureRow(number: "4", icon: "bubble.left.and.text.bubble.right.fill", title: "추가 질문", subtitle: "원하는 에이전트의 근거를 이어 물어요")
            }
        }
    }
}

struct NameOnboarding: View {
    @Binding var name: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(eyebrow: "1 of 5", title: "뭐라고 불러드릴까요?", subtitle: "에이전트들이 회의 중 이 이름을 사용해요.")
            TextField("이름", text: $name)
                .font(.system(size: 21, weight: .bold))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 18)
                .frame(height: 62)
                .chartCard(stroke: isFocused ? ChartTheme.mint : ChartTheme.stroke)
                .focused($isFocused)
                .submitLabel(.continue)
                .onAppear { isFocused = true }
        }
    }
}

struct DifferenceOnboarding: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(
                eyebrow: "Here is the difference",
                title: "한 번의 답과\n검증된 결론은 달라요.",
                subtitle: "같은 차트도 반론을 거치면 조건과 위험이 선명해집니다."
            )

            VerifiedDecisionBoard()
        }
    }
}

private struct VerifiedDecisionBoard: View {
    private let roleIcons = [
        "chart.line.uptrend.xyaxis",
        "waveform.path.ecg",
        "bolt.fill",
        "shield.lefthalf.filled",
        "arrow.triangle.2.circlepath"
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 13) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ChartTheme.coral)
                    .frame(width: 44, height: 44)
                    .background(ChartTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("한 번의 답")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(ChartTheme.coral)
                    Text("즉시 매수")
                        .font(.system(size: 20, weight: .black))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("반론 없음", systemImage: "xmark.circle.fill")
                    Label("무효화 없음", systemImage: "xmark.circle.fill")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
            }
            .padding(14)
            .background(ChartTheme.coral.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ChartTheme.coral.opacity(0.30), lineWidth: 1)
            }

            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                Text("VS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
                Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("5 AGENT CROSS-CHECK")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(ChartTheme.mint)
                        Text("서로 다른 근거가 하나의 판단으로 모여요")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ChartTheme.mint)
                }

                HStack(spacing: 6) {
                    ForEach(Array(PixelAgent.team.enumerated()), id: \.element.id) { index, agent in
                        VStack(spacing: 7) {
                            Image(systemName: roleIcons[index])
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(agent.accent)
                                .frame(width: 42, height: 42)
                                .background(agent.accent.opacity(0.13), in: Circle())
                                .overlay { Circle().stroke(agent.accent.opacity(0.34), lineWidth: 1) }
                            Text(agent.localizedRole)
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.76))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(ChartTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("조건부 관망")
                            .font(.system(size: 18, weight: .black))
                        Text("확인선 회복 시 진입 · 이탈 시 판단 폐기")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ChartTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(ChartTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(15)
            .background(Color(red: 0.027, green: 0.060, blue: 0.059), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ChartTheme.mint.opacity(0.34), lineWidth: 1)
            }
        }
        .padding(14)
        .chartCard(fill: Color(red: 0.022, green: 0.034, blue: 0.040), stroke: .white.opacity(0.10), radius: 24)
    }
}

struct GrowthOnboarding: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(
                eyebrow: "Evidence compounds",
                title: "근거가 쌓일수록\n판단은 더 선명해져요.",
                subtitle: "정답을 약속하는 대신, 반복할 수 있는 검증 순서를 만듭니다."
            )

            EvidenceGrowthChart(progress: progress)
                .frame(height: 280)
                .padding(16)
                .chartCard(fill: Color(red: 0.028, green: 0.050, blue: 0.056), stroke: ChartTheme.mint.opacity(0.30))

            HStack(spacing: 12) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(ChartTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("분석할수록 남는 것은 감이 아닌 기준")
                        .font(.system(size: 15, weight: .bold))
                    Text("확인선 · 무효화 · 반대 전환 조건을 같은 순서로 점검")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                }
            }
            .padding(14)
            .chartCard()
        }
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeInOut(duration: 1.45).delay(0.18)) {
                    progress = 1
                }
            }
        }
    }
}

private struct EvidenceGrowthChart: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(1..<5, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(0.065))
                        .frame(height: 1)
                        .offset(y: proxy.size.height * CGFloat(index) / 5)
                }

                EvidenceGrowthArea()
                    .fill(
                        LinearGradient(
                            colors: [ChartTheme.mint.opacity(0.28), ChartTheme.mint.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(progress)

                EvidenceGrowthLine()
                    .trim(from: 0, to: progress)
                    .stroke(ChartTheme.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .shadow(color: ChartTheme.mint.opacity(0.45), radius: 8)

                EvidenceBaselineLine()
                    .trim(from: 0, to: progress)
                    .stroke(ChartTheme.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: ChartTheme.coral.opacity(0.26), radius: 5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("EVIDENCE PATH")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(ChartTheme.mint)
                    HStack(spacing: 12) {
                        legend("검증 누적", color: ChartTheme.mint)
                        legend("단일 관점", color: ChartTheme.coral)
                    }
                }
                .padding(10)
            }
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(AppLanguage.localized(title))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
        }
    }
}

private struct EvidenceGrowthLine: Shape {
    private let values: [CGFloat] = [0.86, 0.80, 0.72, 0.76, 0.57, 0.48, 0.38, 0.29, 0.13]

    func path(in rect: CGRect) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let point = CGPoint(
                    x: rect.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: rect.height * value
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }
    }
}

private struct EvidenceGrowthArea: Shape {
    private let values: [CGFloat] = [0.86, 0.80, 0.72, 0.76, 0.57, 0.48, 0.38, 0.29, 0.13]

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height))
            for (index, value) in values.enumerated() {
                path.addLine(to: CGPoint(
                    x: rect.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: rect.height * value
                ))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.closeSubpath()
        }
    }
}

private struct EvidenceBaselineLine: Shape {
    private let values: [CGFloat] = [0.86, 0.80, 0.87, 0.78, 0.85, 0.76, 0.83, 0.79, 0.84]

    func path(in rect: CGRect) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let point = CGPoint(
                    x: rect.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: rect.height * value
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }
    }
}
