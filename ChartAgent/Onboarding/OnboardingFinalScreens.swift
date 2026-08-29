import SwiftUI

struct TeamTrustOnboarding: View {
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(
                eyebrow: "Meet the team",
                title: "한 차트를 보는\n다섯 명의 전문 에이전트.",
                subtitle: "서로 다른 임무를 맡고, 근거가 충돌하면 반드시 반론합니다."
            )

            AgentCouncilFormation()
                .frame(height: 230)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(PixelAgent.team.enumerated()), id: \.element.id) { index, agent in
                    AgentIntroductionCard(agent: agent)
                        .staggeredEntrance(index: index + 1)
                }
            }
        }
    }
}

private struct AgentCouncilFormation: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.032, green: 0.052, blue: 0.060))

                Circle()
                    .fill(ChartTheme.mint.opacity(0.07))
                    .frame(width: 178, height: 178)
                    .overlay { Circle().stroke(ChartTheme.mint.opacity(0.16), lineWidth: 1) }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 8)

                VStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(ChartTheme.mint)
                    Text("ONE CHART")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(width: 80, height: 64)
                .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 18))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 7)
                .zIndex(2)

                ForEach(Array(PixelAgent.team.enumerated()), id: \.element.id) { index, agent in
                    let point = formationPoint(index: index, size: proxy.size)
                    VStack(spacing: -6) {
                        PixelAgentView(
                            agent: agent,
                            direction: direction(index),
                            pose: .idle,
                            scale: index == 2 ? 0.80 : 0.68
                        )
                        Text(agent.localizedName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(agent.accent)
                    }
                    .position(point)
                    .zIndex(2)
                }

                Path { path in
                    for index in PixelAgent.team.indices {
                        let point = formationPoint(index: index, size: proxy.size)
                        path.move(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2 + 7))
                        path.addLine(to: point)
                    }
                }
                .stroke(ChartTheme.mint.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .zIndex(1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ChartTheme.mint.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func formationPoint(index: Int, size: CGSize) -> CGPoint {
        let points: [UnitPoint] = [
            UnitPoint(x: 0.22, y: 0.30),
            UnitPoint(x: 0.78, y: 0.30),
            UnitPoint(x: 0.50, y: 0.79),
            UnitPoint(x: 0.18, y: 0.76),
            UnitPoint(x: 0.82, y: 0.76)
        ]
        let point = points[index]
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func direction(_ index: Int) -> PixelDirection {
        switch index {
        case 0, 3: .right
        case 1, 4: .left
        default: .front
        }
    }
}

private struct AgentIntroductionCard: View {
    let agent: PixelAgent

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: agent.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(agent.accent)
                    .frame(width: 28, height: 28)
                    .background(agent.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.localizedName)
                        .font(.system(size: 14, weight: .black))
                    Text(agent.localizedRole)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(agent.accent)
                }
                Spacer(minLength: 0)
            }
            Text(agent.localizedMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ChartTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .chartCard(stroke: agent.accent.opacity(0.20), radius: 16)
    }
}

struct ReadyOnboarding: View {
    let profile: OnboardingProfile

    var displayName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppLanguage.localized("트레이더")
            : profile.name
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("AGENT ROOM READY")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(ChartTheme.mint)
                Text(
                    String.localizedStringWithFormat(
                        AppLanguage.localized("%@님의\n분석팀이 준비됐어요."),
                        displayName
                    )
                )
                    .font(.system(size: 31, weight: .black))
                    .multilineTextAlignment(.center)
                Text(
                    String.localizedStringWithFormat(
                        AppLanguage.localized("%@ 문제를 먼저 점검하도록\n다섯 에이전트의 회의 순서를 맞췄어요."),
                        profile.challenge.title
                    )
                )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            PixelOfficeView(
                focusedAgentIndex: 4,
                bubbleText: PixelAgent.team[4].localizedMessage,
                isAnalyzing: false,
                height: 330
            )

            HStack(spacing: 8) {
                statusChip(icon: "person.3.fill", text: "5명 접속")
                statusChip(icon: "checkmark.shield.fill", text: "검증 모드")
                statusChip(icon: "bubble.left.and.text.bubble.right.fill", text: "후속 대화")
            }
        }
    }

    private func statusChip(icon: String, text: String) -> some View {
        Label(AppLanguage.localized(text), systemImage: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(ChartTheme.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ChartTheme.mintDeep, in: Capsule())
    }
}
