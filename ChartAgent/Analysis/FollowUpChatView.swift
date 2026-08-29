import SwiftUI

struct AgentQuestionDestination: Identifiable {
    let id = UUID()
}

struct AgentQuestionEntryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "message.fill")
                    .font(.title3.bold())
                    .foregroundStyle(ChartTheme.mint)
                    .frame(width: 46, height: 46)
                    .background(ChartTheme.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("에이전트에게 후속 질문").font(.headline.bold())
                    Text("리포트를 보면서 한 명씩 바로 대화하세요.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(ChartTheme.mint, in: Circle())
            }
            .padding(16)
            .chartCard(fill: ChartTheme.surfaceRaised, stroke: ChartTheme.stroke, radius: 18)
        }
        .onboardingBeam(active: !reduceMotion, cornerRadius: 18)
        .buttonStyle(.plain)
    }
}

struct AgentQuestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var analysisStore: AnalysisStore

    let analysis: AnalysisRecord

    @State private var selectedAgentID = PixelAgent.team[0].id
    @State private var draft = ""
    @State private var turns: [FollowUpTurn] = []
    @State private var isLoading = false
    @State private var scrollRevision = 0
    @State private var didLoadHistory = false
    @FocusState private var isEditorFocused: Bool

    private var selectedAgent: PixelAgent {
        resolvedAgent(id: selectedAgentID)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            conversationArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChartTheme.background.ignoresSafeArea())
        .clipped()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if turns.isEmpty { suggestions }
                composer
            }
            .background(ChartTheme.surface)
        }
        .onAppear(perform: loadHistory)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(analysisAgents) { agent in
                    Button {
                        selectedAgentID = agent.id
                    } label: {
                        Label("\(agent.localizedName) · \(agent.localizedRole)", systemImage: agent.icon)
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    PixelAgentView(agent: selectedAgent, direction: .front, pose: .idle, phase: 0, scale: 0.54)
                        .frame(width: 36, height: 43)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(selectedAgent.localizedName).font(.headline.bold()).foregroundStyle(.white)
                            Image(systemName: "chevron.down").font(.caption2.bold()).foregroundStyle(ChartTheme.secondaryText)
                        }
                        Text(selectedAgent.localizedRole)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(selectedAgent.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("답변 에이전트 변경")

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ChartAgent AI")
                    .font(.subheadline.bold())
                Text("\(analysis.symbol.code) · \(analysis.timeframe)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(ChartTheme.secondaryText)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("후속 질문 닫기")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ChartTheme.background)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    if turns.isEmpty {
                        emptyConversation
                    } else {
                        ForEach(turns) { turn in
                            conversation(turn)
                        }
                    }
                    Color.clear.frame(height: 1).id("chat-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollRevision) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyConversation: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 54)
            PixelAgentView(agent: selectedAgent, direction: .front, pose: .talking, phase: 0, scale: 1.02)
                .frame(width: 70, height: 82)
                .background(selectedAgent.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
            VStack(spacing: 7) {
                Text(String.localizedStringWithFormat(AppLanguage.localized("%@에게 물어보세요"), selectedAgent.localizedName))
                    .font(.system(size: 22, weight: .bold))
                Text("이 리포트의 차트 근거와 무효화 조건 안에서 답합니다.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 54)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var suggestions: some View {
        VStack(spacing: 7) {
            ForEach(Array(analysis.result.followUpSuggestions.prefix(3)), id: \.self) { prompt in
                Button {
                    draft = prompt
                    isEditorFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.caption2.bold())
                            .foregroundStyle(selectedAgent.accent)
                        Text(MarketLanguage.localizedTerms(in: prompt))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 13))
                    .overlay { RoundedRectangle(cornerRadius: 13).stroke(ChartTheme.stroke) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(String.localizedStringWithFormat(AppLanguage.localized("%@에게 메시지 보내기"), selectedAgent.localizedName), text: $draft, axis: .vertical)
                .focused($isEditorFocused)
                .font(.subheadline.weight(.medium))
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(ChartTheme.stroke) }

            Button { Task { await submit() } } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .black))
                    }
                }
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(selectedAgent.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.36)
            .accessibilityLabel("질문 보내기")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(ChartTheme.surface)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
    }

    private var canSubmit: Bool {
        !isLoading && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func conversation(_ turn: FollowUpTurn) -> some View {
        let agent = resolvedAgent(id: turn.agentID)
        return VStack(spacing: 11) {
            HStack {
                Spacer(minLength: 58)
                Text(MarketLanguage.localizedTerms(in: turn.question))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.leading, 10)

            HStack(alignment: .top, spacing: 9) {
                PixelAgentView(agent: agent, direction: .front, pose: .talking, phase: 0, scale: 0.52)
                    .frame(width: 36, height: 43)
                VStack(alignment: .leading, spacing: 8) {
                    Text(agent.localizedName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(agent.accent)

                    if turn.isPending {
                        HStack(spacing: 8) {
                            ProgressView().tint(agent.accent)
                            Text("리포트 근거를 확인하는 중…")
                                .foregroundStyle(ChartTheme.secondaryText)
                        }
                    } else if let response = turn.response {
                        Text(MarketLanguage.localizedTerms(in: response.answer))
                            .foregroundStyle(.white.opacity(0.90))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(Color.white.opacity(0.08))
                        Label(MarketLanguage.localizedTerms(in: response.caveat), systemImage: "exclamationmark.shield.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChartTheme.amber)
                    } else if let failure = turn.failure {
                        Text(failure.localizedDescription)
                            .foregroundStyle(ChartTheme.coral)
                        if let recovery = failure.recoverySuggestion {
                            Text(recovery)
                                .font(.caption)
                                .foregroundStyle(ChartTheme.secondaryText)
                        }
                    }
                }
                .font(.subheadline.weight(.medium))
                .lineSpacing(4)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.trailing, 18)
        }
    }

    private var analysisAgents: [PixelAgent] {
        PixelAgent.defaultTeam.map { base in
            guard let profile = analysis.agentProfiles?.first(where: { $0.roleID == base.id })?.profile else {
                return PixelAgent.team.first(where: { $0.id == base.id }) ?? base
            }
            return base.applying(profile)
        }
    }

    private func resolvedAgent(id: String) -> PixelAgent {
        analysisAgents.first(where: { $0.id == id }) ?? analysisAgents[0]
    }

    @MainActor
    private func submit() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return }

        let agentID = selectedAgentID
        let turnID = UUID()
        turns.append(FollowUpTurn(id: turnID, agentID: agentID, question: question))
        draft = ""
        isEditorFocused = false
        isLoading = true
        scrollRevision += 1

        do {
            let history = turns.compactMap { turn -> FollowUpHistoryItem? in
                guard let response = turn.response else { return nil }
                return FollowUpHistoryItem(agentId: turn.agentID, question: turn.question, answer: response.answer)
            }
            let response = try await ChartAgentAPI.shared.followUp(
                agentID: agentID,
                question: question,
                analysis: analysis,
                history: Array(history.suffix(12))
            )
            if let index = turns.firstIndex(where: { $0.id == turnID }) {
                turns[index].response = response
            }
            analysisStore.saveFollowUpTurn(
                SavedFollowUpTurn(
                    id: turnID,
                    analysisId: analysis.id,
                    agentId: agentID,
                    question: question,
                    answer: response.answer,
                    caveat: response.caveat,
                    provider: response.provider,
                    createdAt: Date()
                )
            )
        } catch let error as ChartAgentAPIError {
            if let index = turns.firstIndex(where: { $0.id == turnID }) {
                turns[index].failure = error
            }
        } catch {
            if let index = turns.firstIndex(where: { $0.id == turnID }) {
                turns[index].failure = .transport(error.localizedDescription)
            }
        }

        isLoading = false
        scrollRevision += 1
    }

    private func loadHistory() {
        guard !didLoadHistory else { return }
        didLoadHistory = true
        let saved = analysisStore.followUpTurns(for: analysis.id)
        turns = saved.map(FollowUpTurn.init(saved:))
        if let last = saved.last,
           PixelAgent.team.contains(where: { $0.id == last.agentId }) {
            selectedAgentID = last.agentId
        }
        if !turns.isEmpty { scrollRevision += 1 }
    }
}

private struct FollowUpTurn: Identifiable {
    let id: UUID
    let agentID: String
    let question: String
    var response: FollowUpResponse?
    var failure: ChartAgentAPIError?

    var isPending: Bool { response == nil && failure == nil }

    init(id: UUID, agentID: String, question: String, response: FollowUpResponse? = nil, failure: ChartAgentAPIError? = nil) {
        self.id = id
        self.agentID = agentID
        self.question = question
        self.response = response
        self.failure = failure
    }

    init(saved: SavedFollowUpTurn) {
        id = saved.id
        agentID = saved.agentId
        question = saved.question
        response = FollowUpResponse(
            agentId: saved.agentId,
            answer: saved.answer,
            caveat: saved.caveat,
            provider: saved.provider
        )
        failure = nil
    }
}
