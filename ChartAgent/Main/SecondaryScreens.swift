import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var analysisStore: AnalysisStore
    @State private var selectedRecord: AnalysisRecord?

    var body: some View {
        List {
            screenTitle("분석 기록", subtitle: "에이전트 판단과 차트 근거를 다시 확인하세요")
                .padding(.top, 14)
                .reportsMainScrollOffset()
                .listRowInsets(EdgeInsets(top: 0, leading: ChartTheme.screenPadding, bottom: 20, trailing: ChartTheme.screenPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            HStack(spacing: 10) {
                metric(value: "\(analysisStore.records.count)", label: "분석 기록")
                metric(value: "\(analysisStore.records.filter(\.includedNews).count)", label: "뉴스 반영")
            }
            .listRowInsets(EdgeInsets(top: 0, leading: ChartTheme.screenPadding, bottom: 16, trailing: ChartTheme.screenPadding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if analysisStore.records.isEmpty {
                VStack(spacing: 11) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundStyle(ChartTheme.mint)
                    Text("저장된 분석이 없습니다").font(.headline)
                    Text("홈에서 차트 분석을 완료하면 실제 결과가 여기에 쌓입니다.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .chartCard()
                .listRowInsets(EdgeInsets(top: 0, leading: ChartTheme.screenPadding, bottom: 28, trailing: ChartTheme.screenPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(analysisStore.records) { record in
                    historyRow(record)
                        .listRowInsets(EdgeInsets(top: 0, leading: ChartTheme.screenPadding, bottom: 12, trailing: ChartTheme.screenPadding))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    analysisStore.remove(record)
                                }
                            } label: {
                                Label("삭제", systemImage: "trash.fill")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 28, for: .scrollContent)
        .coordinateSpace(name: "main-tab-scroll")
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

    private func historyRow(_ record: AnalysisRecord) -> some View {
        Button { selectedRecord = record } label: {
            HStack(spacing: 14) {
                historyImage(record)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(MarketLanguage.symbolLabel(record.symbol)).font(.headline)
                        Spacer()
                        Text(stanceLabel(record.result.consensus.stanceCode))
                            .font(.caption.bold())
                            .foregroundStyle(stanceColor(record.result.consensus.stanceCode))
                    }
                    Text(MarketLanguage.recordStrategy(record))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(MarketLanguage.historyTimestamp(record.createdAt))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                }
            }
            .padding(14)
            .chartCard()
        }
        .buttonStyle(.plain)
    }

    private func stanceLabel(_ code: String) -> String {
        MarketLanguage.stanceLabel(code)
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
                .frame(width: 88, height: 68)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 13))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(ChartTheme.secondaryText)
                .frame(width: 88, height: 68)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 30, weight: .black, design: .rounded))
            Text(AppLanguage.localized(label).uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.5)
                .foregroundStyle(ChartTheme.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chartCard()
    }
}

private struct LegacyAgentsView: View {
    @State private var selectedAgentID: String?
    @AppStorage("activeAgentIDs") private var storedActiveAgentIDs = PixelAgent.team.map(\.id).joined(separator: ",")

    private var activeAgentIDs: Set<String> {
        let allowed = Set(PixelAgent.team.map(\.id))
        let stored = Set(storedActiveAgentIDs.split(separator: ",").map(String.init)).intersection(allowed)
        return stored.count >= 3 ? stored : allowed
    }

    private var selectedAgent: PixelAgent {
        PixelAgent.team.first(where: { $0.id == selectedAgentID }) ?? PixelAgent.team[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    screenTitle("리서치 플로어", subtitle: "오늘의 분석 위원회를 직접 구성하세요")
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(activeAgentIDs.count)/5")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(ChartTheme.mint)
                        Text("ACTIVE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ChartTheme.secondaryText)
                    }
                }

                PixelOfficeView(
                    focusedAgentIndex: nil,
                    bubbleText: nil,
                    isAnalyzing: false,
                    height: 560,
                    selectedAgentID: $selectedAgentID
                )

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("오늘의 위원회", systemImage: "person.3.sequence.fill")
                            .font(.headline.bold())
                        Spacer()
                        Text("에이전트 선택")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                    ForEach(PixelAgent.team) { agent in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                                selectedAgentID = agent.id
                            }
                        } label: {
                            HStack(spacing: 12) {
                                PixelAgentView(agent: agent, direction: .front, pose: selectedAgentID == agent.id ? .talking : .idle, phase: 0, scale: 0.58)
                                    .frame(width: 39, height: 45)
                                    .background(agent.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 7) {
                                        Text(agent.localizedName).font(.subheadline.bold())
                                        Text(agent.localizedRole)
                                            .font(.caption2.bold())
                                            .foregroundStyle(agent.accent)
                                    }
                                    Text(agent.localizedSpecialty)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(ChartTheme.secondaryText)
                                }
                                Spacer()
                                Toggle("", isOn: activeBinding(for: agent.id))
                                    .labelsHidden()
                                    .tint(agent.accent)
                                    .disabled(activeAgentIDs.count == 3 && activeAgentIDs.contains(agent.id))
                            }
                            .padding(11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .chartCard(fill: selectedAgentID == agent.id ? agent.accent.opacity(0.10) : ChartTheme.surface, stroke: selectedAgentID == agent.id ? agent.accent.opacity(0.40) : ChartTheme.stroke, radius: 15)
                    }
                }

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Label("위원회 균형", systemImage: "scale.3d")
                            .font(.headline.bold())
                        Spacer()
                        Text(balanceLabel)
                            .font(.caption.bold())
                            .foregroundStyle(balanceColor)
                    }
                    councilBalance
                    Text(activeAgentIDs.count < 5
                         ? "선택한 \(activeAgentIDs.count)명의 관점으로 다음 회의를 진행합니다. 최소 3명은 유지해야 합니다."
                         : "추세·패턴·모멘텀·리스크·반대 검증이 모두 포함된 균형 위원회입니다.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                        .lineSpacing(3)
                }
                .padding(17)
                .chartCard(fill: ChartTheme.mintDeep.opacity(0.28), stroke: ChartTheme.mint.opacity(0.22), radius: 17)

                VStack(alignment: .leading, spacing: 12) {
                    Label("선택한 에이전트의 회의 원칙", systemImage: selectedAgent.icon)
                        .font(.headline.bold())
                        .foregroundStyle(selectedAgent.accent)
                    Text(selectedAgent.localizedDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineSpacing(4)
                    HStack(spacing: 8) {
                        principleChip(selectedAgent.localizedRole, color: selectedAgent.accent)
                        principleChip("독립 검토", color: .white)
                    }
                }
                .padding(17)
                .chartCard(stroke: selectedAgent.accent.opacity(0.28), radius: 17)
            }
            .padding(.horizontal, ChartTheme.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .reportsMainScrollOffset()
        }
        .coordinateSpace(name: "main-tab-scroll")
    }

    private func activeBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { activeAgentIDs.contains(id) },
            set: { isOn in
                var updated = activeAgentIDs
                if isOn {
                    updated.insert(id)
                } else if updated.count > 3 {
                    updated.remove(id)
                }
                storedActiveAgentIDs = PixelAgent.team.map(\.id).filter(updated.contains).joined(separator: ",")
            }
        )
    }

    private var councilBalance: some View {
        HStack(spacing: 5) {
            ForEach(PixelAgent.team) { agent in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(activeAgentIDs.contains(agent.id) ? agent.accent : Color.white.opacity(0.08))
                        .frame(height: 8)
                    Text(String(agent.localizedName.prefix(1)))
                        .font(.caption2.bold())
                        .foregroundStyle(activeAgentIDs.contains(agent.id) ? .white : .white.opacity(0.28))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var balanceLabel: String {
        AppLanguage.localized(activeAgentIDs.count == 5 ? "전체 관점" : (activeAgentIDs.count == 4 ? "균형" : "집중"))
    }

    private var balanceColor: Color {
        activeAgentIDs.count >= 4 ? ChartTheme.mint : ChartTheme.amber
    }

    private func principleChip(_ text: String, color: Color) -> some View {
        Text(AppLanguage.localized(text))
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.10), in: Capsule())
    }
}

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var analysisStore: AnalysisStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileExperience") private var profileExperience = TradingExperience.intermediate.rawValue
    @AppStorage("profileMarket") private var profileMarket = MarketFocus.crypto.rawValue
    @AppStorage("profileStyle") private var profileStyle = TradingStyle.swing.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue
    @State private var isPaywallPresented = false
    @State private var presentedLegalDocument: LegalDocumentKind?
    @State private var isLicensesPresented = false
    @State private var isClearConfirmationPresented = false
    @State private var statusMessage = ""
    @State private var isStatusAlertPresented = false
    @State private var isProfileEditorPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                screenTitle("마이", subtitle: "내 분석 환경과 앱 설정을 관리하세요")

                Button {
                    isProfileEditorPresented = true
                } label: {
                    HStack(spacing: 16) {
                        PixelAgentView(agent: PixelAgent.team[0], pose: .idle, phase: 0, scale: 0.9)
                            .frame(width: 64, height: 68)
                            .background(ChartTheme.mintDeep, in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileName.isEmpty ? AppLanguage.localized("트레이더") : profileName)
                                .font(.title3.bold())
                            Text(profileSummary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ChartTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.30))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(18)
                .chartCard()

                settingsSection(title: "구독") {
                    HStack(spacing: 12) {
                        Image(systemName: subscriptionStore.isProActive ? "checkmark.seal.fill" : "sparkles")
                            .foregroundStyle(subscriptionStore.isProActive ? ChartTheme.mint : ChartTheme.amber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppLanguage.localized(subscriptionStore.isProActive ? "ChartAgent PRO 활성" : "무료 이용 중"))
                                .font(.subheadline.bold())
                            if subscriptionStore.isProActive {
                                Text("모든 분석 결과와 후속 대화를 이용할 수 있습니다.")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ChartTheme.secondaryText)
                            }
                        }
                        Spacer()
                    }

                    Divider().overlay(ChartTheme.stroke)

                    settingButton(
                        icon: subscriptionStore.isProActive ? "creditcard.fill" : "crown.fill",
                        title: subscriptionStore.isProActive ? "구독 관리" : "PRO 플랜 보기"
                    ) {
                        if subscriptionStore.isProActive {
                            openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                        } else {
                            isPaywallPresented = true
                        }
                    }

                    Divider().overlay(ChartTheme.stroke)

                    Button {
                        restorePurchases()
                    } label: {
                        HStack {
                            if subscriptionStore.isRestoring {
                                ProgressView().tint(ChartTheme.mint).frame(width: 28)
                            } else {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(ChartTheme.mint)
                                    .frame(width: 28)
                            }
                            Text("구매 복원").font(.subheadline.bold())
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(subscriptionStore.isRestoring)
                }

                settingsSection(title: "앱") {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundStyle(ChartTheme.mint)
                            .frame(width: 28)
                        Text("앱 언어")
                            .font(.subheadline.bold())
                        Spacer(minLength: 8)
                        Menu {
                            ForEach(AppLanguage.allCases) { language in
                                Button(language.title) {
                                    appLanguage = language.rawValue
                                    AppLanguage.select(rawValue: language.rawValue)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedAppLanguage.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .allowsTightening(true)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.bold())
                            }
                            .foregroundStyle(ChartTheme.mint)
                            .frame(maxWidth: 120, alignment: .trailing)
                        }
                    }
                }

                settingsSection(title: "데이터") {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .foregroundStyle(ChartTheme.mint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("기기 저장 분석").font(.subheadline.bold())
                            Text(
                                String.localizedStringWithFormat(
                                    AppLanguage.localized("%@개의 분석과 후속 대화가 이 기기에 저장되어 있습니다."),
                                    String(analysisStore.records.count)
                                )
                            )
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ChartTheme.secondaryText)
                        }
                        Spacer()
                    }

                    if !analysisStore.records.isEmpty {
                        Divider().overlay(ChartTheme.stroke)
                        Button(role: .destructive) {
                            isClearConfirmationPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill").frame(width: 28)
                                Text("모든 분석 기록 삭제").font(.subheadline.bold())
                                Spacer()
                            }
                            .foregroundStyle(ChartTheme.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsSection(title: "정보 및 약관") {
                    settingButton(icon: "hand.raised.fill", title: "개인정보 처리 안내") {
                        presentedLegalDocument = .privacyPolicy
                    }

                    Divider().overlay(ChartTheme.stroke)

                    settingButton(icon: "doc.text.fill", title: "이용약관") {
                        presentedLegalDocument = .termsOfUse
                    }

                    Divider().overlay(ChartTheme.stroke)

                    settingButton(icon: "curlybraces", title: "오픈소스 라이선스") {
                        isLicensesPresented = true
                    }
                }

                Text(
                    String.localizedStringWithFormat(
                        AppLanguage.localized("ChartAgent · %@ (%@)\nAI 키와 시장 데이터 키는 서버에만 보관됩니다."),
                        appVersion,
                        buildNumber
                    )
                )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.34))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, ChartTheme.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .reportsMainScrollOffset()
        }
        .coordinateSpace(name: "main-tab-scroll")
        .sheet(isPresented: $isProfileEditorPresented) {
            ProfileEditorSheet()
                .presentationDetents([.fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(ChartTheme.background)
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView(
                onSubscribed: { isPaywallPresented = false },
                onDismiss: { isPaywallPresented = false }
            )
        }
        .sheet(item: $presentedLegalDocument) { kind in
            LegalDocumentSheet(kind: kind)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChartTheme.background)
        }
        .sheet(isPresented: $isLicensesPresented) {
            OpenSourceLicensesView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChartTheme.background)
        }
        .confirmationDialog("모든 분석 기록을 삭제할까요?", isPresented: $isClearConfirmationPresented, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) {
                analysisStore.removeAllAnalyses()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장된 이미지, 분석 결과, 후속 대화가 이 기기에서 삭제되며 되돌릴 수 없습니다.")
        }
        .alert("구매 복원", isPresented: $isStatusAlertPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }

    private var profileSummary: String {
        let style = TradingStyle(rawValue: profileStyle)?.title ?? AppLanguage.localized("스타일 미설정")
        let market = MarketFocus(rawValue: profileMarket)?.title ?? AppLanguage.localized("시장 미설정")
        let experience = TradingExperience(rawValue: profileExperience)?.title ?? AppLanguage.localized("경험 미설정")
        return "\(style) · \(market) · \(experience)"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func restorePurchases() {
        Task {
            do {
                let restored = try await subscriptionStore.restore()
                statusMessage = AppLanguage.localized(restored ? "PRO 구독을 복원했습니다." : "복원할 활성 PRO 구독을 찾지 못했습니다.")
            } catch {
                statusMessage = error.localizedDescription
            }
            isStatusAlertPresented = true
        }
    }

    private func settingsSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.black))
                .tracking(2)
                .foregroundStyle(ChartTheme.secondaryText)
            VStack(spacing: 14, content: content)
                .padding(18)
                .chartCard()
        }
    }

    private func settingButton(icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundStyle(ChartTheme.mint).frame(width: 28)
                Text(title).font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.26))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var storedName = ""
    @AppStorage("profileExperience") private var storedExperience = TradingExperience.intermediate.rawValue
    @AppStorage("profileMarket") private var storedMarket = MarketFocus.crypto.rawValue
    @AppStorage("profileStyle") private var storedStyle = TradingStyle.swing.rawValue

    @State private var draftName: String
    @State private var draftExperience: TradingExperience
    @State private var draftMarket: MarketFocus
    @State private var draftStyle: TradingStyle

    init() {
        let defaults = UserDefaults.standard
        _draftName = State(initialValue: defaults.string(forKey: "profileName") ?? "")
        _draftExperience = State(
            initialValue: TradingExperience(
                rawValue: defaults.string(forKey: "profileExperience") ?? ""
            ) ?? .intermediate
        )
        _draftMarket = State(
            initialValue: MarketFocus(
                rawValue: defaults.string(forKey: "profileMarket") ?? ""
            ) ?? .crypto
        )
        _draftStyle = State(
            initialValue: TradingStyle(
                rawValue: defaults.string(forKey: "profileStyle") ?? ""
            ) ?? .swing
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(AppLanguage.localized("이름"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(ChartTheme.secondaryText)
                        TextField(AppLanguage.localized("이름"), text: $draftName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                    }

                    choiceMenu(
                        title: AppLanguage.localized("투자 경험"),
                        selection: $draftExperience,
                        options: Array(TradingExperience.allCases)
                    )
                    choiceMenu(
                        title: AppLanguage.localized("관심 시장"),
                        selection: $draftMarket,
                        options: Array(MarketFocus.allCases)
                    )
                    choiceMenu(
                        title: AppLanguage.localized("거래 스타일"),
                        selection: $draftStyle,
                        options: Array(TradingStyle.allCases)
                    )
                }
                .padding(ChartTheme.screenPadding)
            }
            .background(ChartTheme.background)
            .navigationTitle(AppLanguage.localized("내 정보 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLanguage.localized("취소")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLanguage.localized("저장")) { save() }
                        .fontWeight(.bold)
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: draftName) { _, value in
                if value.count > 20 {
                    draftName = String(value.prefix(20))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func choiceMenu<Option: TradingChoice>(
        title: String,
        selection: Binding<Option>,
        options: [Option]
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(ChartTheme.secondaryText)
            Menu {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack {
                            Text(option.title)
                            if selection.wrappedValue == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selection.wrappedValue.icon)
                        .foregroundStyle(ChartTheme.mint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selection.wrappedValue.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(selection.wrappedValue.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(ChartTheme.mint)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 66)
                .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func save() {
        storedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        storedExperience = draftExperience.rawValue
        storedMarket = draftMarket.rawValue
        storedStyle = draftStyle.rawValue
        dismiss()
    }
}

private struct OpenSourceLicensesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                licenseRow("BorderBeamKit", detail: "MIT License · Jakub Antalík")
                licenseRow("RevenueCat Purchases", detail: "MIT License · RevenueCat")
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("오픈소스 라이선스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func licenseRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline.bold())
            Text(detail).font(.caption.weight(.medium)).foregroundStyle(ChartTheme.secondaryText)
        }
        .padding(.vertical, 6)
    }
}

private func screenTitle(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 29, weight: .black))
        Text(subtitle)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ChartTheme.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
