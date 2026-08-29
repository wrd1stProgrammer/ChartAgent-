import SwiftUI
import UIKit
import BorderBeamKit

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var analysisStore: AnalysisStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @AppStorage(FreeAnalysisAccess.storageKey) private var hasUsedFreeAnalysis = false
    @State private var isUploadPresented = false
    @State private var isPaywallPresented = false
    @State private var uploadSheetDetent: PresentationDetent = .fraction(0.80)
    @State private var selectedAgentID: String?
    @State private var selectedRecord: AnalysisRecord?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                PixelOfficeView(
                    focusedAgentIndex: nil,
                    bubbleText: nil,
                    isAnalyzing: false,
                    isAutonomous: true,
                    height: 470,
                    selectedAgentID: $selectedAgentID
                )
                analysisStartButton
                recentSection
                InvestmentDisclaimerView()
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
            .padding(.horizontal, ChartTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .reportsMainScrollOffset()
        }
        .coordinateSpace(name: "main-tab-scroll")
        .sheet(isPresented: $isUploadPresented) {
            AnalysisUploadView()
                .presentationDetents([.fraction(0.80), .large], selection: $uploadSheetDetent)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            ProPaywallView(
                onSubscribed: { isPaywallPresented = false },
                onDismiss: { isPaywallPresented = false }
            )
        }
        .fullScreenCover(item: $selectedRecord) { record in
            ZStack {
                AppBackground()
                SubscriptionGatedResultView(
                    record: record,
                    imageData: analysisStore.imageData(for: record),
                    onClose: { selectedRecord = nil }
                )
            }
        }
    }

    private var analysisStartAccess: AnalysisStartAccess {
        AnalysisStartAccessPolicy.access(
            isEntitlementResolved: subscriptionStore.isEntitlementResolved,
            hasProAccess: subscriptionStore.isProActive,
            hasUsedFreeAnalysis: FreeAnalysisAccess.hasBeenUsed(
                storedValue: hasUsedFreeAnalysis,
                hasExistingAnalysis: !analysisStore.records.isEmpty
            )
        )
    }

    private var analysisStartButton: some View {
        Button {
            switch analysisStartAccess {
            case .available:
                uploadSheetDetent = .fraction(0.80)
                isUploadPresented = true
            case .locked:
                isPaywallPresented = true
            case .checking:
                break
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: analysisStartAccess == .locked ? "lock.fill" : "viewfinder.circle.fill")
                    .font(.title2)
                Text(analysisStartButtonTitle)
                    .font(.system(size: 19, weight: .black))
                Spacer()
                Text(analysisStartBadgeTitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.15), in: Capsule())
            }
            .foregroundStyle(analysisStartAccess == .available ? .black : .white.opacity(0.62))
            .padding(.horizontal, 18)
            .frame(height: 64)
            .background(
                analysisStartAccess == .available ? ChartTheme.mint : ChartTheme.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(analysisStartAccess == .locked ? ChartTheme.stroke : .clear, lineWidth: 1)
            }
            .shadow(
                color: ChartTheme.mint.opacity(analysisStartAccess == .available ? 0.30 : 0),
                radius: 26,
                y: 8
            )
        }
        .borderBeam(
            .line,
            colorVariant: .mono,
            theme: .dark,
            active: analysisStartAccess == .available && !reduceMotion,
            borderRadius: 20,
            strength: 0.97
        )
        .buttonStyle(.plain)
        .disabled(analysisStartAccess == .checking)
    }

    private var analysisStartButtonTitle: String {
        switch analysisStartAccess {
        case .checking: AppLanguage.localized("구독 상태 확인 중")
        case .available: AppLanguage.localized("차트 분석 시작")
        case .locked: AppLanguage.localized("PRO 플랜 보기")
        }
    }

    private var analysisStartBadgeTitle: String {
        guard analysisStartAccess != .locked else { return "PRO" }
        return String.localizedStringWithFormat(
            AppLanguage.localized("%@ AGENTS"),
            String(activeAgentCount)
        )
    }

    private var activeAgentCount: Int {
        PixelAgent.defaultTeam.count
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("AI TRADING OFFICE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(ChartTheme.mint)
                Text("다섯 에이전트가 차트를 기다려요").font(.system(size: 22, weight: .black))
            }
            Spacer()
            Label("5 ONLINE", systemImage: "circle.fill")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(ChartTheme.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ChartTheme.mintDeep, in: Capsule())
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 분석").font(.system(size: 20, weight: .bold))
            if let record = analysisStore.latest {
                Button { selectedRecord = record } label: {
                    HStack(spacing: 14) {
                        historyImage(record)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .center) {
                                Text(MarketLanguage.symbolLabel(record.symbol)).font(.headline)
                                Spacer()
                                Text(MarketLanguage.stanceLabel(record.result.consensus.stanceCode))
                                    .font(.caption.bold())
                                    .foregroundStyle(stanceColor(record.result.consensus.stanceCode))
                            }
                            Text(MarketLanguage.recordStrategy(record))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.74))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Label(MarketLanguage.historyTimestamp(record.createdAt), systemImage: "clock")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ChartTheme.secondaryText)
                        }
                    }
                    .padding(14)
                    .chartCard()
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 13) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(ChartTheme.mint)
                        .frame(width: 48, height: 48)
                        .background(ChartTheme.mintDeep, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("아직 분석 기록이 없어요").font(.headline)
                        Text("첫 차트 분석을 마치면 이곳에서 바로 다시 볼 수 있습니다.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                }
                .padding(15)
                .chartCard()
            }
        }
    }

    private func stanceColor(_ code: String) -> Color {
        switch MarketLanguage.normalizedStanceCode(code) {
        case "bullish": ChartTheme.mint
        case "bearish": ChartTheme.coral
        case "neutral": ChartTheme.violet
        default: ChartTheme.amber
        }
    }

    @ViewBuilder
    private func historyImage(_ record: AnalysisRecord) -> some View {
        if let data = analysisStore.imageData(for: record), let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 106, height: 78)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 13))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(ChartTheme.secondaryText)
                .frame(width: 106, height: 78)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 13))
        }
    }
}
