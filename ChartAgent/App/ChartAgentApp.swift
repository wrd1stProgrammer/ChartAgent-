import SwiftUI
#if DEBUG
import UIKit
#endif

@main
struct ChartAgentApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage(FreeAnalysisAccess.storageKey) private var hasUsedFreeAnalysis = false
    @State private var isShowingLaunchOverlay = true
    @StateObject private var analysisStore = AnalysisStore()
    @StateObject private var analysisRunCoordinator = AnalysisRunCoordinator()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var agentProfileStore = AgentProfileStore.shared

    init() {
        AttributionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootView
                    .id(selectedLanguage.responseLanguage)

                if isShowingLaunchOverlay {
                    ChartAgentLaunchOverlay {
                        isShowingLaunchOverlay = false
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .environmentObject(analysisStore)
            .environmentObject(analysisRunCoordinator)
            .environmentObject(subscriptionStore)
            .environmentObject(agentProfileStore)
            .preferredColorScheme(.dark)
            .tint(ChartTheme.mint)
            .environment(\.locale, selectedLanguage.locale)
            .task {
                if !analysisStore.records.isEmpty {
                    hasUsedFreeAnalysis = true
                }
                await subscriptionStore.refreshEntitlement()
                if hasCompletedOnboarding {
                    try? await Task.sleep(for: .seconds(1))
                    await AttributionService.shared.requestTrackingAuthorizationIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppLanguage.didChangeNotification)) { notification in
                guard let rawValue = notification.object as? String else { return }
                appLanguage = rawValue
            }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        let screen = environment["CHARTAGENT_SCREEN"]
            ?? arguments.first(where: { $0.hasPrefix("--chartagent-screen=") })?
                .replacingOccurrences(of: "--chartagent-screen=", with: "")
        switch screen {
        case "annotations":
            ChartAnnotationPreview()
        case "onboarding":
            OnboardingFlow(onComplete: {})
        case "paywall":
            ProPaywallView(onSubscribed: {}, onDismiss: {})
        case "home":
            ZStack { AppBackground(); HomeView() }
                .environment(MainTabBarScrollState())
        case "upload":
            AnalysisUploadView()
        case "office_roam":
            ZStack {
                AppBackground()
                PixelOfficeView(
                    focusedAgentIndex: nil,
                    bubbleText: nil,
                    isAnalyzing: false,
                    isAutonomous: true,
                    height: 520
                )
                .padding(20)
            }
        case "agents":
            ZStack { AppBackground(); AgentsView() }
                .environment(MainTabBarScrollState())
        case "history":
            ZStack { AppBackground(); HistoryView() }
                .environment(MainTabBarScrollState())
        case "profile":
            ZStack { AppBackground(); ProfileView() }
                .environment(MainTabBarScrollState())
        case "meeting", "meeting_table", "meeting_move", "meeting_trend", "meeting_dissent":
            AnalysisUploadView()
        case "office_seated":
            ZStack {
                AppBackground()
                PixelOfficeView(
                    focusedAgentIndex: nil,
                    bubbleText: nil,
                    isAnalyzing: true,
                    height: 520
                )
                .padding(20)
            }
        case "sprite_front":
            SpriteQAView(direction: .front, pose: .idle)
        case "sprite_back":
            SpriteQAView(direction: .back, pose: .idle)
        case "sprite_walk_left":
            SpriteQAView(direction: .left, pose: .walking)
        case "sprite_sit_back":
            SpriteQAView(direction: .back, pose: .sitting)
        case "result", "result_news", "question":
            AnalysisResultView(
                record: DebugPreviewData.analysisRecord,
                imageData: DebugPreviewData.chartImageData,
                onClose: {}
            )
        default:
            defaultRoot
        }
#else
        defaultRoot
#endif
    }

    @ViewBuilder
    private var defaultRoot: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingFlow {
                completeOnboarding()
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            await AttributionService.shared.requestTrackingAuthorizationIfNeeded()
        }
    }
}

#if DEBUG
private enum DebugPreviewData {
    static let chartImageData: Data? = {
        let size = CGSize(width: 720, height: 420)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let drawing = context.cgContext
            UIColor(red: 0.015, green: 0.045, blue: 0.06, alpha: 1).setFill()
            drawing.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.08).setStroke()
            drawing.setLineWidth(1)
            for column in stride(from: 60.0, through: size.width, by: 60.0) {
                drawing.move(to: CGPoint(x: column, y: 0))
                drawing.addLine(to: CGPoint(x: column, y: size.height))
            }
            for row in stride(from: 52.0, through: size.height, by: 52.0) {
                drawing.move(to: CGPoint(x: 0, y: row))
                drawing.addLine(to: CGPoint(x: size.width, y: row))
            }
            drawing.strokePath()

            let closes: [CGFloat] = [286, 260, 274, 238, 252, 220, 198, 216, 184, 164, 190, 154, 132, 148, 116, 136, 104, 84]
            for (index, close) in closes.enumerated() {
                let x = 48 + CGFloat(index) * 35
                let rising = index == 0 || close <= closes[index - 1]
                let color = rising ? UIColor(red: 0.16, green: 0.92, blue: 0.67, alpha: 1) : UIColor(red: 1, green: 0.31, blue: 0.43, alpha: 1)
                color.setStroke()
                color.setFill()
                drawing.setLineWidth(3)
                drawing.move(to: CGPoint(x: x, y: close - 22))
                drawing.addLine(to: CGPoint(x: x, y: close + 34))
                drawing.strokePath()
                drawing.fill(CGRect(x: x - 8, y: close, width: 16, height: 26))
            }

            UIColor(red: 0.24, green: 0.55, blue: 1, alpha: 0.9).setStroke()
            drawing.setLineWidth(4)
            drawing.move(to: CGPoint(x: 36, y: 306))
            drawing.addCurve(
                to: CGPoint(x: 676, y: 126),
                control1: CGPoint(x: 210, y: 282),
                control2: CGPoint(x: 468, y: 198)
            )
            drawing.strokePath()
        }.jpegData(compressionQuality: 0.9)
    }()

    static let analysisRecord = AnalysisRecord(
        id: "ipad-layout-preview",
        createdAt: .now,
        provider: "preview",
        symbol: MarketSymbol(code: "BTCUSD", name: "Bitcoin", instrumentType: "crypto"),
        timeframe: "4H",
        includedNews: true,
        result: AnalysisPayload(
            validation: ChartValidationResult(
                isChart: true,
                isReadable: true,
                detectedSymbol: "BTCUSD",
                detectedTimeframe: "4H",
                reasonCode: "ok",
                message: ""
            ),
            consensus: ConsensusResult(
                title: "관망",
                stanceCode: "wait",
                confidence: 72,
                summary: "현재 지지 구간에서는 추격하지 않고 확인 캔들을 기다립니다."
            ),
            scope: AnalysisScopeResult(visible: ["가격 구조", "캔들"], unavailable: []),
            agentOpinions: [
                opinion("trend", "추세는 유지되지만 확인 전 진입은 보류합니다."),
                opinion("pattern", "반전 캔들이 완성되는지 먼저 확인합니다."),
                opinion("momentum", "모멘텀이 회복되는 구간만 선별합니다."),
                opinion("risk", "지지 이탈 시 판단을 즉시 무효화합니다."),
                opinion("devil", "페이크아웃 뒤 재진입 가능성을 반대로 검증합니다."),
            ],
            scenarios: [
                AnalysisScenario(title: "상승 확인", condition: "저항 위에서 종가가 안착", action: "재시험 뒤 진입을 검토합니다.", tone: "bullish"),
                AnalysisScenario(title: "기본 대기", condition: "가격이 범위 안에서 횡보", action: "확인 전까지 포지션을 보류합니다.", tone: "neutral"),
                AnalysisScenario(title: "하락 확인", condition: "지지 아래에서 종가가 마감", action: "반등 재시험을 기다립니다.", tone: "bearish"),
            ],
            structure: [
                StructureLevel(label: "현재가", value: "63,050", note: "표시 가격", tone: "neutral"),
                StructureLevel(label: "지지", value: "62,000", note: "최근 저점", tone: "bullish"),
                StructureLevel(label: "저항", value: "65,600", note: "최근 고점", tone: "bearish"),
            ],
            meetingScript: [],
            dataQuality: DataQualityResult(chart: "good", priceAxis: "good", timeframe: "good", news: "included"),
            newsImpact: NewsImpactResult(
                collectedCount: 20,
                usedCount: 8,
                effect: "reinforced",
                summary: "관련 뉴스는 차트의 대기 판단을 보강했습니다.",
                usedTitles: ["시장 변동성 확대"]
            ),
            tradePlan: TradePlanResult(
                directionCode: "wait",
                referencePrice: "63,050",
                entry: "64,390",
                stop: "62,000",
                target: "67,300",
                riskReward: "1:2",
                trigger: "확인 캔들 이후 재시험",
                rationale: "현재가 추격 대신 확인된 구간만 사용합니다."
            ),
            followUpSuggestions: ["무효화 조건을 다시 설명해 줘"]
        ),
        news: [],
        agentProfiles: PixelAgent.defaultTeam.map(AgentProfile.defaultProfile).map(AgentProfileSnapshot.init)
    )

    private static func opinion(_ agentID: String, _ thesis: String) -> AgentOpinion {
        AgentOpinion(
            agentId: agentID,
            stanceCode: "wait",
            stance: "관망",
            confidence: 72,
            thesis: thesis,
            evidence: ["표시된 가격 구조를 기준으로 판단했습니다."]
        )
    }
}
#endif

private struct ChartAgentLaunchOverlay: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isExiting = false

    var body: some View {
        ZStack {
            ChartTheme.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [ChartTheme.mint.opacity(0.12), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 250
            )
            .ignoresSafeArea()

            HStack(spacing: 14) {
                Image("AppIconPixelSignalCandles")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ChartTheme.mint.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: ChartTheme.mint.opacity(0.22), radius: 18)

                Text(verbatim: "ChartAgent")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .opacity(isVisible && !isExiting ? 1 : 0)
            .blur(radius: reduceMotion || (isVisible && !isExiting) ? 0 : 8)
            .scaleEffect(reduceMotion || (isVisible && !isExiting) ? 1 : 0.94)
            .offset(y: reduceMotion || (isVisible && !isExiting) ? 0 : 8)
            .animation(.easeOut(duration: reduceMotion ? 0.16 : 0.48), value: isVisible)
            .animation(.easeInOut(duration: reduceMotion ? 0.16 : 0.34), value: isExiting)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ChartAgent")
        }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 90))
            guard !Task.isCancelled else { return }
            isVisible = true

            try? await Task.sleep(for: .milliseconds(reduceMotion ? 620 : 1_050))
            guard !Task.isCancelled else { return }
            isExiting = true

            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 360))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}

#if DEBUG
private struct SpriteQAView: View {
    let direction: PixelDirection
    let pose: PixelAgentPose

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: pose != .walking)) { timeline in
            VStack(spacing: 22) {
                Text("FULL BODY SPRITE QA")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(ChartTheme.mint)
                HStack(spacing: 6) {
                    ForEach(Array(PixelAgent.team.enumerated()), id: \.element.id) { index, agent in
                        PixelAgentView(
                            agent: agent,
                            direction: direction,
                            pose: pose,
                            phase: timeline.date.timeIntervalSinceReferenceDate + Double(index) * 0.12,
                            scale: 1.25,
                            showsName: true
                        )
                        .frame(width: 72, height: 108)
                    }
                }
                Text("\(String(describing: direction).uppercased()) · \(String(describing: pose).uppercased())")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
        }
    }
}
#endif
