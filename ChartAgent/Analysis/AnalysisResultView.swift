import BorderBeamKit
import SwiftUI
import UIKit

enum TradePriceLevelFormatter {
    static func displayValue(from source: String) -> String {
        let normalized = source.replacingOccurrences(of: "—", with: "–")
        let pattern = #"[0-9][0-9,]*(?:\.[0-9]+)?(?:\s*[–~-]\s*[0-9][0-9,]*(?:\.[0-9]+)?)?"#
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized)
           ),
           let range = Range(match.range, in: normalized) {
            return String(normalized[range])
                .replacingOccurrences(of: #"\s*[–~-]\s*"#, with: "–", options: .regularExpression)
        }

        let description = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty || description == "–" ? "—" : description
    }
}

struct AnalysisResultView: View {
    @EnvironmentObject private var analysisStore: AnalysisStore

    let record: AnalysisRecord
    let imageData: Data?
    let isContentLocked: Bool
    let onClose: () -> Void

    @State private var expandedAgentID: String?
    @State private var questionDestination: AgentQuestionDestination?
    @State private var isNewsExpanded = false
    @State private var isDeleteConfirmationPresented = false

    init(
        record: AnalysisRecord,
        imageData: Data?,
        isContentLocked: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.record = record
        self.imageData = imageData
        self.isContentLocked = isContentLocked
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            resultHeader
            ScrollViewReader { scroll in
              ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    chartPreview(scroll: scroll)
                    decisionCard
                    tradeSetupCard
                    scenarios
                    marketStructure
                    agentJudgements
                    if record.includedNews { newsContext }
                    dataConfidence
                    AgentQuestionEntryCard {
                        if !isContentLocked {
                            questionDestination = AgentQuestionDestination()
                        }
                    }
                    .allowsHitTesting(!isContentLocked)
                    InvestmentDisclaimerView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, ChartTheme.screenPadding)
                .padding(.bottom, 30)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
              }
            }
        }
        .background(ChartTheme.background.ignoresSafeArea())
        .confirmationDialog(
            "분석 기록을 삭제할까요?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                analysisStore.remove(record)
                onClose()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 이 분석과 저장된 후속 대화가 기기에서 제거됩니다.")
        }
        .sheet(item: $questionDestination) { _ in
            AgentQuestionSheet(analysis: record)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(ChartTheme.background)
        }
    }

    private var resultHeader: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(ChartTheme.surfaceRaised, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(MarketLanguage.symbolLabel(record.symbol)) · \(record.timeframe)")
                    .font(.headline.bold())
                Text(
                    String.localizedStringWithFormat(
                        AppLanguage.localized("%@인 에이전트 실제 분석 리포트"),
                        String(record.result.agentOpinions.count)
                    )
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChartTheme.secondaryText)
            }
            Spacer()
            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Image(systemName: "trash")
                    .font(.headline)
                    .foregroundStyle(ChartTheme.coral)
                    .frame(width: 42, height: 42)
                    .background(ChartTheme.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("분석 기록 삭제")
        }
        .padding(.horizontal, ChartTheme.screenPadding)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func chartPreview(scroll: ScrollViewProxy) -> some View {
        if let imageData {
            ChartAnnotationCard(
                analysisID: record.id,
                imageData: imageData,
                analysis: record.result,
                onScenarioSelected: { index in
                    withAnimation { scroll.scrollTo("chart-scenario-\(index)", anchor: .top) }
                },
                isLocked: isContentLocked
            )
        }
    }

    private var decisionCard: some View {
        let consensus = record.result.consensus
        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("현재 판단")
                        .font(.caption.weight(.black))
                        .tracking(1.5)
                        .foregroundStyle(ChartTheme.mint)
                    Text(stanceLabel)
                        .font(.system(size: 25, weight: .black))
                        .analysisSensitive(isContentLocked)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Text("근거 강도")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ChartTheme.secondaryText)
                    Text(evidenceStrength.label)
                        .font(.headline.bold())
                        .foregroundStyle(evidenceStrength.color)
                        .analysisSensitive(isContentLocked)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index < evidenceStrength.segments ? evidenceStrength.color : Color.white.opacity(0.10))
                                .frame(width: 18, height: 5)
                        }
                    }
                }
            }
            Text("종합 매매전략")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(stanceColor)
            Text(MarketLanguage.localizedTerms(in: consensus.summary))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .lineSpacing(5)
                .analysisSensitive(isContentLocked)
        }
        .padding(20)
        .chartCard(fill: ChartTheme.mintDeep.opacity(0.38), stroke: ChartTheme.mint.opacity(0.34))
        .borderBeam(
            .pulseInner,
            colorVariant: .ocean,
            theme: .dark,
            borderRadius: ChartTheme.corner,
            strength: 0.97
        )
    }

    private var tradeSetupCard: some View {
        let plan = resolvedTradePlan
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionHeader("실행 가격 지도", detail: "추격하지 않는 진입·손절·목표", icon: "scope")
                Spacer(minLength: 10)
                Text(displayRiskReward(plan))
                    .font(.caption.weight(.black))
                    .foregroundStyle(ChartTheme.mint)
                    .analysisSensitive(isContentLocked)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ChartTheme.mint.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 8) {
                tradeLevel("진입", value: plan.entry, color: ChartTheme.mint, icon: "arrow.right.circle.fill")
                tradeLevel("손절", value: plan.stop, color: ChartTheme.coral, icon: "xmark.octagon.fill")
                tradeLevel("목표", value: plan.target, color: ChartTheme.blue, icon: "flag.checkered")
            }

            VStack(alignment: .leading, spacing: 7) {
                Label(MarketLanguage.localizedTerms(in: plan.trigger), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
                    .analysisSensitive(isContentLocked)
                Text(MarketLanguage.localizedTerms(in: plan.rationale))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .analysisSensitive(isContentLocked)
            }
        }
        .padding(17)
        .chartCard(fill: ChartTheme.surfaceRaised, stroke: ChartTheme.mint.opacity(0.24), radius: 18)
    }

    private func tradeLevel(_ title: LocalizedStringKey, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(TradePriceLevelFormatter.displayValue(from: MarketLanguage.localizedTerms(in: value)))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(2)
                .minimumScaleFactor(0.70)
                .analysisSensitive(isContentLocked)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.18)) }
    }

    private func displayRiskReward(_ plan: TradePlanResult) -> String {
        let entries = numericValues(in: plan.entry)
        let stops = numericValues(in: plan.stop)
        let targets = numericValues(in: plan.target)
        guard !entries.isEmpty, !stops.isEmpty, !targets.isEmpty else {
            return fallbackRiskReward(plan.riskReward)
        }

        let direction = MarketLanguage.normalizedStanceCode(plan.directionCode)
        let entry: Double
        let stop: Double
        let target: Double
        if direction == "bearish" {
            entry = entries.min() ?? 0
            stop = stops.max() ?? 0
            target = targets.max() ?? 0
        } else if direction == "bullish" {
            entry = entries.max() ?? 0
            stop = stops.min() ?? 0
            target = targets.min() ?? 0
        } else {
            let candidateEntry = entries.reduce(0, +) / Double(entries.count)
            let candidateStop = stops.reduce(0, +) / Double(stops.count)
            let candidateTarget = targets.reduce(0, +) / Double(targets.count)
            entry = candidateEntry
            stop = candidateStop
            target = candidateTarget
        }

        let isShort = direction == "bearish" || (direction == "observe" && stop > entry && target < entry)
        let risk = isShort ? stop - entry : entry - stop
        let reward = isShort ? entry - target : target - entry
        guard risk > 0, reward > 0, risk.isFinite, reward.isFinite else {
            return fallbackRiskReward(plan.riskReward)
        }
        let ratio = reward / risk
        let formatted = ratio.rounded() == ratio ? String(format: "%.0f", ratio) : String(format: "%.1f", ratio)
        return "1:\(formatted)"
    }

    private func numericValues(in source: String) -> [Double] {
        guard let expression = try? NSRegularExpression(pattern: #"[0-9][0-9,]*(?:\.[0-9]+)?"#) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let valueRange = Range(match.range, in: source) else { return nil }
            return Double(source[valueRange].replacingOccurrences(of: ",", with: ""))
        }
    }

    private func fallbackRiskReward(_ source: String) -> String {
        let pattern = #"1\s*:\s*[0-9]+(?:\.[0-9]+)?"#
        guard let range = source.range(of: pattern, options: .regularExpression) else {
            return AppLanguage.localized("손익비 조건부")
        }
        return String(source[range].replacingOccurrences(of: " ", with: ""))
    }

    private var resolvedTradePlan: TradePlanResult {
        record.result.tradePlan ?? TradePlanResult(
            directionCode: record.result.consensus.stanceCode,
            referencePrice: AppLanguage.localized("차트 표시가"),
            entry: AppLanguage.localized("확인선 재시험"),
            stop: AppLanguage.localized("무효화선 바깥"),
            target: AppLanguage.localized("다음 가시 경계"),
            riskReward: AppLanguage.localized("최소 1:1.8"),
            trigger: record.result.scenarios.first?.condition ?? AppLanguage.localized("확인 조건이 완성될 때까지 가격을 추격하지 않습니다."),
            rationale: record.result.consensus.summary
        )
    }

    private var stanceLabel: String {
        MarketLanguage.stanceLabel(record.result.consensus.stanceCode)
    }

    private var evidenceStrength: EvidenceStrength {
        EvidenceStrength(score: record.result.consensus.confidence)
    }

    private var stanceColor: Color {
        switch MarketLanguage.normalizedStanceCode(record.result.consensus.stanceCode) {
        case "bullish": ChartTheme.mint
        case "bearish": ChartTheme.coral
        default: ChartTheme.amber
        }
    }

    private var agentJudgements: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("에이전트별 판단", detail: "각 전문 관점의 결론과 근거", icon: "person.3.fill")
            VStack(spacing: 0) {
                ForEach(record.result.agentOpinions) { opinion in
                    LiveAgentOpinionRow(
                        opinion: opinion,
                        profile: record.agentProfiles?.first { $0.roleID == opinion.agentId },
                        isExpanded: expandedAgentID == opinion.agentId,
                        isContentLocked: isContentLocked
                    ) {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
                            expandedAgentID = expandedAgentID == opinion.agentId ? nil : opinion.agentId
                        }
                    }
                    if opinion.id != record.result.agentOpinions.last?.id {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .chartCard(radius: 16)
        }
    }

    private var scenarios: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("조건별 시나리오", detail: "이미지 근거가 바뀔 때의 대응", icon: "arrow.triangle.branch")
            VStack(spacing: 9) {
                ForEach(Array(record.result.scenarios.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(color(for: item.tone)).frame(width: 8, height: 8).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(MarketLanguage.localizedTerms(in: item.title)).font(.subheadline.bold())
                            Text(MarketLanguage.localizedTerms(in: item.condition))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ChartTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .analysisSensitive(isContentLocked)
                            Text(MarketLanguage.localizedTerms(in: item.action))
                                .font(.caption.bold())
                                .foregroundStyle(color(for: item.tone))
                                .fixedSize(horizontal: false, vertical: true)
                                .analysisSensitive(isContentLocked)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .chartCard(fill: ChartTheme.surfaceRaised, radius: 14)
                    .id("chart-scenario-\(index)")
                }
            }
        }
    }

    private var marketStructure: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("보이는 구조", detail: "읽을 수 없는 숫자는 상대 조건으로 표시", icon: "point.3.connected.trianglepath.dotted")
            VStack(spacing: 9) {
                ForEach(record.result.structure) { level in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(MarketLanguage.localizedTerms(in: level.label))
                                .font(.caption.bold())
                                .foregroundStyle(ChartTheme.secondaryText)
                            Spacer(minLength: 12)
                            Text(MarketLanguage.compactStructureValue(in: level.value))
                                .font(.subheadline.bold())
                                .foregroundStyle(color(for: level.tone))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)
                                .analysisSensitive(isContentLocked)
                        }
                        Text(MarketLanguage.localizedTerms(in: level.note))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.76))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .analysisSensitive(isContentLocked)
                    }
                    .padding(14)
                    .chartCard(fill: ChartTheme.surfaceRaised, radius: 14)
                }
            }
        }
    }

    private var newsContext: some View {
        let impact = resolvedNewsImpact
        let usedTitles = Set(impact.usedTitles)
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("뉴스 반영 내역", detail: newsImpactDetail(impact), icon: "newspaper.fill")
            if record.news.isEmpty {
                Text("선택한 심볼과 직접 연결된 최신 뉴스가 없어 차트 근거만 사용했습니다.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .padding(16)
                    .chartCard(radius: 14)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(newsEffect.label)
                            .font(.caption.weight(.black))
                            .foregroundStyle(newsEffect.color)
                        Text(MarketLanguage.localizedTerms(in: impact.summary))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                            .analysisSensitive(isContentLocked)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isNewsExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(newsDisclosureTitle)
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: isNewsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(ChartTheme.mint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isNewsExpanded {
                        Divider().overlay(Color.white.opacity(0.08))
                        newsBucket("최근 24시간", items: recentNews, usedTitles: usedTitles)
                        if !priorNews.isEmpty {
                            Divider().overlay(Color.white.opacity(0.08))
                            newsBucket("24–48시간", items: priorNews, usedTitles: usedTitles)
                        }
                    }
                }
                .padding(14)
                .chartCard(radius: 14)
            }
        }
    }

    private var resolvedNewsImpact: NewsImpactResult {
        record.result.newsImpact ?? NewsImpactResult(
            collectedCount: record.news.count,
            usedCount: 0,
            effect: "none",
            summary: AppLanguage.localized("이전 분석 기록에는 뉴스 사용 내역이 저장되지 않아 출처만 표시합니다."),
            usedTitles: []
        )
    }

    private var newsDisclosureTitle: String {
        if isNewsExpanded { return AppLanguage.localized("뉴스 접기") }
        return String.localizedStringWithFormat(
            AppLanguage.localized("수집 뉴스 %@건 보기"),
            String(record.news.count)
        )
    }

    private func newsImpactDetail(_ impact: NewsImpactResult) -> String {
        let format = AppLanguage.localized("최근 48시간 · %@/%@건 반영")
        return String.localizedStringWithFormat(
            format,
            String(impact.usedCount),
            String(impact.collectedCount)
        )
    }

    private var recentNews: [NewsReference] {
        record.news.filter { record.createdAt.timeIntervalSince($0.date) < 86_400 }
    }

    private var priorNews: [NewsReference] {
        record.news.filter {
            let age = record.createdAt.timeIntervalSince($0.date)
            return age >= 86_400 && age < 172_800
        }
    }

    private func newsBucket(_ title: String, items: [NewsReference], usedTitles: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(
                String.localizedStringWithFormat(
                    AppLanguage.localized("%@ · %@건"),
                    AppLanguage.localized(title),
                    String(items.count)
                )
            )
                .font(.caption.weight(.black))
                .foregroundStyle(ChartTheme.secondaryText)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.source).font(.caption2.bold()).foregroundStyle(ChartTheme.mint)
                        Spacer()
                        Label(
                            AppLanguage.localized(usedTitles.contains(item.title) ? "분석 반영" : "참고 수집"),
                            systemImage: usedTitles.contains(item.title) ? "checkmark.circle.fill" : "circle"
                        )
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(usedTitles.contains(item.title) ? ChartTheme.mint : ChartTheme.secondaryText)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.subheadline.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .analysisSensitive(isContentLocked)
                        Spacer(minLength: 10)
                        Text(item.date.formatted(.relative(presentation: .numeric).locale(AppLanguage.current.locale)))
                            .font(.caption2)
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                }
                .padding(.vertical, 2)
                if index < items.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
    }

    private var newsEffect: NewsEffectPresentation {
        NewsEffectPresentation(code: resolvedNewsImpact.effect)
    }

    private var dataConfidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("입력 품질", detail: "판독에 실제 사용된 데이터 상태", icon: "checkmark.shield.fill")
            HStack(spacing: 8) {
                qualityCell("차트", record.result.dataQuality.chart)
                qualityCell("가격 축", record.result.dataQuality.priceAxis)
                qualityCell("시간대", record.result.dataQuality.timeframe)
                qualityCell("뉴스", resolvedNewsQuality)
            }
        }
    }

    private var resolvedNewsQuality: String {
        let impact = resolvedNewsImpact
        if impact.usedCount > 0 { return "included" }
        if impact.collectedCount > 0 || !record.news.isEmpty { return "unused" }
        return record.includedNews ? "empty" : "unused"
    }

    private func qualityCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(localizedQuality(value)).font(.caption2.bold()).foregroundStyle(qualityColor(value))
            Text(AppLanguage.localized(title)).font(.caption2).foregroundStyle(ChartTheme.secondaryText)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .chartCard(fill: ChartTheme.surfaceRaised, radius: 12)
    }

    private func localizedQuality(_ value: String) -> String {
        switch value.lowercased() {
        case "good": AppLanguage.localized("양호")
        case "included": AppLanguage.localized("포함")
        case "partial": AppLanguage.localized("일부")
        case "provided": AppLanguage.localized("제공됨")
        case "empty": AppLanguage.localized("없음")
        case "unused": AppLanguage.localized("미사용")
        default: AppLanguage.localized(value)
        }
    }

    private func qualityColor(_ value: String) -> Color {
        switch value {
        case "good", "included": ChartTheme.mint
        case "partial", "provided", "empty": ChartTheme.amber
        case "unused": ChartTheme.secondaryText
        default: ChartTheme.coral
        }
    }

    private func color(for tone: String) -> Color {
        switch tone {
        case "mint": ChartTheme.mint
        case "coral": ChartTheme.coral
        case "blue": ChartTheme.blue
        case "violet": ChartTheme.violet
        default: ChartTheme.amber
        }
    }

    private func sectionHeader(_ title: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(AppLanguage.localized(title), systemImage: icon).font(.headline.bold())
            Text(AppLanguage.localized(detail))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChartTheme.secondaryText)
        }
    }
}

struct ChartImageViewerDestination: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ChartImageViewer: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage

    @State private var settledScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1

    private var displayedScale: CGFloat {
        min(max(settledScale * gestureScale, 1), 5)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .scaleEffect(displayedScale)
                .gesture(
                    MagnificationGesture()
                        .updating($gestureScale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            settledScale = min(max(settledScale * value, 1), 5)
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settledScale = settledScale > 1 ? 1 : 2
                    }
                }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("차트 이미지")
                    .font(.headline.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이미지 닫기")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.92))
        }
        .preferredColorScheme(.dark)
    }
}

private struct LiveAgentOpinionRow: View {
    let opinion: AgentOpinion
    let profile: AgentProfileSnapshot?
    let isExpanded: Bool
    let isContentLocked: Bool
    let action: () -> Void

    private var agent: PixelAgent {
        let base = PixelAgent.defaultTeam.first { $0.id == opinion.agentId } ?? PixelAgent.defaultTeam[0]
        return profile?.profile.map(base.applying) ?? PixelAgent.team.first { $0.id == opinion.agentId } ?? base
    }

    var body: some View {
        Button(action: isContentLocked ? {} : action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 9) {
                    PixelAgentView(agent: agent, direction: .front, pose: .idle, phase: 0, scale: 0.80, scaleAnchor: .center)
                        .frame(width: 48, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.localizedName).font(.headline.bold())
                        Text(agent.localizedRole)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(MarketLanguage.stanceLabel(opinion.stanceCode ?? opinion.stance))
                        .font(.caption2.bold())
                        .foregroundStyle(agent.accent)
                        .analysisSensitive(isContentLocked)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(agent.accent.opacity(0.10), in: Capsule())
                }
                Text(MarketLanguage.localizedTerms(in: opinion.thesis))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 3)
                    .padding(.trailing, 34)
                    .analysisSensitive(isContentLocked)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(
                            String.localizedStringWithFormat(
                                AppLanguage.localized("판단 근거 · %@"),
                                EvidenceStrength(score: opinion.confidence).label
                            )
                        )
                            .font(.caption2.weight(.black))
                            .foregroundStyle(agent.accent)
                            .analysisSensitive(isContentLocked)
                        ForEach(opinion.evidence, id: \.self) { evidence in
                            Label(MarketLanguage.localizedTerms(in: evidence), systemImage: "circle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.76))
                                .labelStyle(TinyBulletLabelStyle(color: agent.accent))
                                .analysisSensitive(isContentLocked)
                        }
                    }
                    .padding(.trailing, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EvidenceStrength {
    let label: String
    let segments: Int
    let color: Color

    init(score: Int) {
        if score >= 75 {
            label = AppLanguage.localized("강함")
            segments = 3
            color = ChartTheme.mint
        } else if score >= 50 {
            label = AppLanguage.localized("보통")
            segments = 2
            color = ChartTheme.amber
        } else {
            label = AppLanguage.localized("약함")
            segments = 1
            color = ChartTheme.coral
        }
    }
}

private struct NewsEffectPresentation {
    let label: String
    let color: Color

    init(code: String) {
        switch code {
        case "reinforced":
            label = AppLanguage.localized("차트 판단 보강")
            color = ChartTheme.mint
        case "softened":
            label = AppLanguage.localized("판단 강도 낮춤")
            color = ChartTheme.amber
        case "changed":
            label = AppLanguage.localized("기본 시나리오 수정")
            color = ChartTheme.violet
        default:
            label = AppLanguage.localized("결론 영향 없음")
            color = ChartTheme.secondaryText
        }
    }
}

private struct TinyBulletLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(color)
            configuration.title
        }
    }
}

private extension View {
    func analysisSensitive(_ isLocked: Bool) -> some View {
        blur(radius: isLocked ? 8 : 0)
            .accessibilityHidden(isLocked)
    }
}
