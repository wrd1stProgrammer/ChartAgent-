import StoreKit
import SwiftUI

struct AnalysisSessionView: View {
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var analysisStore: AnalysisStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @AppStorage(FreeAnalysisAccess.storageKey) private var hasUsedFreeAnalysis = false
    @AppStorage("chartagent.hasRequestedReviewAfterFirstAnalysis") private var hasRequestedFirstAnalysisReview = false

    let draft: AnalysisDraft
    let runCoordinator: AnalysisRunCoordinator
    let onClose: () -> Void

    @State private var stage = AnalysisStage.scanning
    @State private var meetingStartedAt: Date?
    @State private var councilHuddle: CouncilHuddle?
    @State private var meetingOriginHuddleParticipants: [Int] = []
    @State private var isPreCouncil = false
    @State private var isFullCouncilRound = false
    @State private var activeLine: MeetingLine?
    @State private var workingLine: MeetingLine?
    @State private var transcriptEntries: [MeetingTranscriptEntry] = []
    @State private var transcriptTypingTarget: String?
    @State private var transcriptTypedStatement = ""
    @State private var isTranscriptTyping = false
    @State private var record: AnalysisRecord?
    @State private var failure: ChartAgentAPIError?
    @State private var isResultVisible = false
    @State private var isAnalysisResponseReady = false
    @State private var didRequestMeetingSkip = false
    @State private var hasMeetingReplayStarted = false
    @State private var hasCompletedSmallGroupDiscussion = false
    @State private var selectedAgentID: String?
    @State private var connectionAgentID: String?
    @State private var didTrackAnalysisCompleted = false

    private let meetingDuration = AnalysisMeetingPacing.meetingDuration
    private let huddleDuration = AnalysisMeetingPacing.huddleDuration
    private let huddleLineDuration = AnalysisMeetingPacing.huddleLineDuration
    private let councilLineDuration = AnalysisMeetingPacing.councilLineDuration

    var body: some View {
        ZStack {
            AppBackground()
            if isResultVisible, let record {
                SubscriptionGatedResultView(record: record, imageData: draft.imageData, onClose: onClose)
                    .transition(.opacity)
            } else if let failure {
                failureView(failure)
            } else {
                researchView
            }
        }
        .task(id: draft.id) { await runAnalysis() }
        .task(id: isResultVisible) { await requestReviewAfterFirstResultIfNeeded() }
    }

    private func requestReviewAfterFirstResultIfNeeded() async {
        guard isResultVisible,
              !hasRequestedFirstAnalysisReview,
              analysisStore.records.count == 1 else { return }

        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }

        guard !Task.isCancelled, isResultVisible else { return }
        hasRequestedFirstAnalysisReview = true
        requestReview()
    }

    private var researchView: some View {
        VStack(spacing: 0) {
            sessionHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    stageHeadline
                    researchRail
                    PixelOfficeView(
                        focusedAgentIndex: primarySpeakerIndex,
                        bubbleText: displayedBubbleText,
                        mode: officeMode,
                        isAnalyzing: true,
                        showsMeetingTable: true,
                        height: 520,
                        activeAgentIDs: Set(draft.activeAgentIDs),
                        discussionAgentIndices: discussionAgentIndices,
                        selectedAgentID: $selectedAgentID,
                        onBubbleTypingUpdate: handleBubbleTypingUpdate
                    )
                    meetingTranscript
                }
                .padding(.horizontal, ChartTheme.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 34)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: displayedLine) { _, line in
            prepareTranscriptTyping(for: line)
            appendTranscript(line)
        }
    }

    private var officeMode: PixelOfficeMode {
        if let councilHuddle {
            return .liveHuddle(
                startedAt: councilHuddle.startedAt,
                duration: councilHuddle.duration,
                participants: councilHuddle.participants,
                returnsToStations: councilHuddle.returnsToStations
            )
        }
        if isPreCouncil { return .office }
        if stage == .gathering {
            if let meetingStartedAt {
                if !meetingOriginHuddleParticipants.isEmpty {
                    return .liveMeetingFromHuddle(
                        startedAt: meetingStartedAt,
                        duration: meetingDuration,
                        participants: meetingOriginHuddleParticipants
                    )
                }
                return .liveMeeting(startedAt: meetingStartedAt, duration: meetingDuration)
            }
            return .meeting(progress: 0)
        }
        return AnalysisMeetingPacing.shouldRenderMeetingLayout(
            replayStarted: hasMeetingReplayStarted,
            stageIsMeeting: stage.isMeeting
        ) ? .meeting(progress: 1) : .office
    }

    private var sessionHeader: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(ChartTheme.surfaceRaised, in: Circle())
            }
            Spacer()
            AnalysisSessionHeaderTitle(contextLabel: sessionContextLabel)
            Spacer()
            if isCouncilSkipAvailable {
                Button(action: skipToResult) {
                    HStack(spacing: 4) {
                        Text("SKIP")
                        Image(systemName: "forward.end.fill")
                    }
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(width: 72, height: 34)
                    .background(ChartTheme.mint, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .accessibilityLabel(AppLanguage.localized("회의 건너뛰기"))
            } else {
                Color.clear.frame(width: 72, height: 34)
            }
        }
        .padding(.horizontal, ChartTheme.screenPadding)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.22), value: isCouncilSkipAvailable)
    }

    private var isCouncilSkipAvailable: Bool {
        AnalysisMeetingPacing.shouldOfferSkip(
            hasResult: record != nil,
            completedSmallGroupDiscussion: hasCompletedSmallGroupDiscussion
        )
    }

    private var sessionContextLabel: String {
        let agents = String.localizedStringWithFormat(
            AppLanguage.localized("%@ AGENTS"),
            String(draft.activeAgentIDs.count)
        )
        if let record {
            return "\(MarketLanguage.symbolLabel(record.symbol)) · \(record.timeframe) · \(agents)"
        }
        if draft.activeAgentIDs.count == 5 {
            return AppLanguage.localized("심볼·시간대 자동 판독 · 5 AGENTS")
        }
        return agents
    }

    private var stageHeadline: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(stage.title)
                    .font(.system(size: 25, weight: .black))
                    .contentTransition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .frame(height: 31, alignment: .leading)
                Spacer()
                Text("\(min(stage.rawValue + 1, 11))/11")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(ChartTheme.mint)
            }
            Text(stage.detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ChartTheme.secondaryText)
                .contentTransition(.opacity)
                .lineLimit(2)
                .frame(height: 38, alignment: .topLeading)
            ProgressView(value: Double(stage.rawValue + 1), total: 11)
                .tint(ChartTheme.mint)
                .scaleEffect(y: 1.7)
        }
    }

    private var researchRail: some View {
        HStack(spacing: 0) {
            railItem("증거 수집", icon: "viewfinder", range: 0...1)
            railConnector(done: stage.rawValue > 1)
            railItem("독립 분석", icon: "person.3.sequence.fill", range: 2...5)
            railConnector(done: stage.rawValue > 5)
            railItem("교차 회의", icon: "bubble.left.and.bubble.right.fill", range: 6...9)
            railConnector(done: stage.rawValue > 9)
            railItem("리포트", icon: "doc.text.fill", range: 10...10)
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .chartCard(radius: 16)
    }

    private func railItem(_ title: String, icon: String, range: ClosedRange<Int>) -> some View {
        let active = range.contains(stage.rawValue)
        let done = stage.rawValue > range.upperBound
        return VStack(spacing: 5) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(done || active ? ChartTheme.mint : .white.opacity(0.28))
            Text(AppLanguage.localized(title))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(active ? .white : ChartTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func railConnector(done: Bool) -> some View {
        Rectangle()
            .fill(done ? ChartTheme.mint : Color.white.opacity(0.11))
            .frame(width: 15, height: 2)
            .offset(y: -9)
    }

    private var meetingTranscript: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(AppLanguage.localized("실시간 회의록"))
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(ChartTheme.mint)
                Spacer()
                Circle().fill(ChartTheme.mint).frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(ChartTheme.mint)
            }
            .padding(.bottom, 8)

            if transcriptEntries.isEmpty {
                Text(operationalLog)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(3)
                    .padding(.vertical, 6)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(transcriptEntries.enumerated()), id: \.element.id) { index, entry in
                        let statement = AnalysisMeetingDialogue.visibleBubble(for: entry.line)
                        let isCurrentTypingEntry = index == 0 && transcriptTypingTarget == statement
                        MeetingTranscriptRow(
                            entry: entry,
                            visibleStatement: isCurrentTypingEntry ? transcriptTypedStatement : nil,
                            isTyping: isCurrentTypingEntry && isTranscriptTyping
                        )
                            .padding(.vertical, 12)
                        if index < transcriptEntries.count - 1 {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(14)
        .chartCard(fill: ChartTheme.surfaceRaised.opacity(0.92), radius: 17)
    }

    private var primarySpeakerIndex: Int? {
        if let agentID = connectionAgentID ?? displayedLine?.agentId {
            return PixelAgent.team.firstIndex { $0.id == agentID }
        }
        let activeIndices = PixelAgent.team.indices.filter { draft.activeAgentIDs.contains(PixelAgent.team[$0].id) }
        guard !activeIndices.isEmpty else { return nil }
        return activeIndices[stage.rawValue % activeIndices.count]
    }

    private var displayedLine: MeetingLine? {
        activeLine ?? workingLine
    }

    private func appendTranscript(_ line: MeetingLine?) {
        guard let line, transcriptEntries.first?.line != line else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            transcriptEntries.insert(MeetingTranscriptEntry(line: line), at: 0)
        }
    }

    private func prepareTranscriptTyping(for line: MeetingLine?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            transcriptTypingTarget = line.map { AnalysisMeetingDialogue.visibleBubble(for: $0) }
            transcriptTypedStatement = ""
            isTranscriptTyping = line != nil
        }
    }

    private func handleBubbleTypingUpdate(_ update: OfficeBubbleTypingUpdate) {
        guard transcriptTypingTarget == update.targetText else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            transcriptTypedStatement = update.visibleText
            isTranscriptTyping = update.isTyping
        }
    }

    private var displayedBubbleText: String? {
        if connectionAgentID != nil {
            return AppLanguage.localized(AnalysisMeetingPacing.connectionBubbleKey)
        }
        return displayedLine.map(AnalysisMeetingDialogue.visibleBubble)
    }

    private var discussionAgentIndices: [Int] {
        guard let activeLine else { return [] }
        if isFullCouncilRound {
            return PixelAgent.team.indices.filter {
                draft.activeAgentIDs.contains(PixelAgent.team[$0].id)
            }
        }
        return discussionGroup(for: activeLine)
    }

    private func discussionGroup(for line: MeetingLine) -> [Int] {
        guard let speaker = PixelAgent.team.firstIndex(where: { $0.id == line.agentId }) else { return [] }

        let preferredListeners: [String]
        switch line.stage {
        case "trend": preferredListeners = ["pattern"]
        case "pattern": preferredListeners = ["trend"]
        case "momentum": preferredListeners = ["risk", "devil"]
        case "risk": preferredListeners = ["trend", "pattern"]
        case "dissent": preferredListeners = ["momentum", "risk"]
        default: preferredListeners = ["pattern", "devil"]
        }

        let activeIDs = Set(draft.activeAgentIDs)
        var group = [speaker]
        for id in preferredListeners where activeIDs.contains(id) {
            if let index = PixelAgent.team.firstIndex(where: { $0.id == id }), !group.contains(index) {
                group.append(index)
            }
        }
        let desiredCount = preferredListeners.count + 1
        if group.count < desiredCount {
            for index in PixelAgent.team.indices where activeIDs.contains(PixelAgent.team[index].id) && !group.contains(index) {
                group.append(index)
                if group.count == desiredCount { break }
            }
        }
        return group
    }

    private var operationalLog: String {
        stage.detail
    }

    private func failureView(_ error: ChartAgentAPIError) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: failureIcon(for: error))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(failureTint(for: error))
                .frame(width: 82, height: 82)
                .background(failureTint(for: error).opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
            VStack(spacing: 9) {
                Text(error.localizedDescription).font(.system(size: 24, weight: .black)).multilineTextAlignment(.center)
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ChartTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 30)
            PrimaryButton(title: "입력 화면으로 돌아가기", action: onClose)
            .padding(.horizontal, ChartTheme.screenPadding)
            Spacer()
        }
    }

    private func failureIcon(for error: ChartAgentAPIError) -> String {
        switch error.failureKind {
        case .invalidImage: "photo.badge.exclamationmark"
        case .invalidChart: "chart.xyaxis.line"
        case .aiResponse: "brain.head.profile"
        case .server: "server.rack"
        case .network: "wifi.exclamationmark"
        case .malformedResponse: "doc.badge.exclamationmark"
        }
    }

    private func failureTint(for error: ChartAgentAPIError) -> Color {
        switch error.failureKind {
        case .invalidImage, .invalidChart:
            ChartTheme.amber
        case .aiResponse, .server, .network, .malformedResponse:
            ChartTheme.coral
        }
    }

    private func runAnalysis() async {
        guard record == nil, failure == nil else { return }

        if let cachedRecord = runCoordinator.cachedResult(for: draft.id) {
            record = cachedRecord
            saveCompletedAnalysis(cachedRecord)
            isResultVisible = true
            return
        }
        if let cachedFailure = runCoordinator.cachedFailure(for: draft.id) {
            setFailureWithoutSceneTransition(cachedFailure)
            return
        }

        isAnalysisResponseReady = false
        didRequestMeetingSkip = false
        hasMeetingReplayStarted = false
        hasCompletedSmallGroupDiscussion = false
        connectionAgentID = nil
        selectedAgentID = nil
        workingLine = nil
        let progress = Task {
            await showConnectionRound()
            await advancePreparationStages()
        }
        do {
            let response = try await runCoordinator.analyze(draft)
            isAnalysisResponseReady = true
            await progress.value
            record = response
            saveCompletedAnalysis(response)
            await replayMeeting(response.result)
        } catch is CancellationError {
            isAnalysisResponseReady = true
            await stopPreparation(progress)
            workingLine = nil
            connectionAgentID = nil
        } catch let error as ChartAgentAPIError {
            isAnalysisResponseReady = true
            await stopPreparation(progress)
            AttributionService.shared.track(.analysisFailed)
            setFailureWithoutSceneTransition(error)
        } catch {
            isAnalysisResponseReady = true
            await stopPreparation(progress)
            AttributionService.shared.track(.analysisFailed)
            setFailureWithoutSceneTransition(.transport(error.localizedDescription))
        }
    }

    private func saveCompletedAnalysis(_ record: AnalysisRecord) {
        analysisStore.save(record, imageData: draft.imageData)
        if !didTrackAnalysisCompleted {
            didTrackAnalysisCompleted = true
            AttributionService.shared.track(
                .analysisCompleted,
                properties: [
                    "symbol": record.symbol.code,
                    "timeframe": record.timeframe,
                    "includes_news": record.includedNews
                ]
            )
        }
        if !subscriptionStore.isProActive {
            hasUsedFreeAnalysis = true
        }
    }

    private func stopPreparation(_ task: Task<Void, Never>) async {
        task.cancel()
        await task.value
    }

    private func setFailureWithoutSceneTransition(_ error: ChartAgentAPIError) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            workingLine = nil
            activeLine = nil
            connectionAgentID = nil
            councilHuddle = nil
            meetingOriginHuddleParticipants = []
            isPreCouncil = false
            isFullCouncilRound = false
            didRequestMeetingSkip = false
            hasMeetingReplayStarted = false
            hasCompletedSmallGroupDiscussion = false
            failure = error
        }
    }

    private func advancePreparationStages() async {
        let preparation: [(stage: AnalysisStage, agentID: String, bubbleKey: String, hold: TimeInterval)] = [
            (.evidence, "trend", "차트 이미지 읽는 중…", 2.8),
            (.trend, "pattern", "캔들 경계 분석 중…", 2.8),
            (.pattern, "momentum", "가격행동 강도 분석 중…", 2.8),
            (.momentum, "risk", "화면 안의 자료 분리 중…", 2.8),
            (.risk, "devil", "반대 시나리오 검증 중…", 2.8),
        ]
        for item in preparation where draft.activeAgentIDs.contains(item.agentID) {
            guard !Task.isCancelled else { return }
            setPreparationLine(
                stage: item.stage,
                line: preparationLine(agentID: item.agentID, bubbleKey: item.bubbleKey)
            )
            do { try await Task.sleep(for: .seconds(item.hold)) } catch { return }
        }

        do {
            try await Task.sleep(for: .seconds(AnalysisMeetingPacing.mockRoundLeadTime))
        } catch {
            return
        }

        for line in AnalysisMeetingPacing.mockPreparationRound(activeAgentIDs: draft.activeAgentIDs) {
            guard !Task.isCancelled else { return }
            setPreparationLine(stage: AnalysisMeetingPacing.preparationStage(for: line.agentId), line: line)
            do {
                try await Task.sleep(for: .seconds(AnalysisMeetingPacing.mockPreparationLineDuration))
            } catch {
                return
            }
        }

        let activeWaitingAgentIDs = AnalysisMockDialogues.agentIDs.filter(draft.activeAgentIDs.contains)
        let waitingAgentID = activeWaitingAgentIDs.contains(AnalysisMeetingPacing.responseWaitingAgentID)
            ? AnalysisMeetingPacing.responseWaitingAgentID
            : activeWaitingAgentIDs.last
        if let waitingAgentID, !isAnalysisResponseReady {
            setPreparationLine(
                stage: AnalysisMeetingPacing.preparationStage(for: waitingAgentID),
                line: preparationLine(
                    agentID: waitingAgentID,
                    bubbleKey: AnalysisMeetingPacing.responseWaitingBubbleKey
                )
            )
        } else {
            setPreparationLine(stage: stage, line: nil)
        }

        let responseArrivedDuringInitialWait = await waitForAnalysisResponse(
            upTo: AnalysisMeetingPacing.responseConceptLeadTime
        )
        if !responseArrivedDuringInitialWait, !activeWaitingAgentIDs.isEmpty {
            var waitingLineIndex = 0
            while !Task.isCancelled, !isAnalysisResponseReady {
                let agentID = activeWaitingAgentIDs[waitingLineIndex % activeWaitingAgentIDs.count]
                let concept = AgentConceptMockCopy.concept(for: agentID)
                let bubble = AgentConceptMockCopy.responseWaitingRemark(for: concept)
                setPreparationLine(
                    stage: AnalysisMeetingPacing.preparationStage(for: agentID),
                    line: MeetingLine(
                        stage: meetingStage(for: agentID),
                        agentId: agentID,
                        bubble: bubble,
                        log: bubble
                    )
                )
                waitingLineIndex += 1
                _ = await waitForAnalysisResponse(
                    upTo: AnalysisMeetingPacing.responseConceptLineDuration
                )
            }
        }
        setPreparationLine(stage: stage, line: nil)
    }

    private func waitForAnalysisResponse(upTo duration: TimeInterval) async -> Bool {
        var elapsed: TimeInterval = 0
        while !Task.isCancelled, !isAnalysisResponseReady, elapsed < duration {
            let interval = min(AnalysisMeetingPacing.responseWaitPollInterval, duration - elapsed)
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return isAnalysisResponseReady
            }
            elapsed += interval
        }
        return isAnalysisResponseReady
    }

    private func showConnectionRound() async {
        for agentID in AnalysisMockDialogues.agentIDs where draft.activeAgentIDs.contains(agentID) {
            guard !Task.isCancelled else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                connectionAgentID = agentID
            }
            do {
                try await Task.sleep(for: .seconds(AnalysisMeetingPacing.connectionLineDuration))
            } catch {
                return
            }
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            connectionAgentID = nil
        }
    }

    private func setPreparationLine(stage nextStage: AnalysisStage, line: MeetingLine?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stage = AnalysisMeetingPacing.nonRegressingPreparationStage(
                current: stage,
                candidate: nextStage
            )
            workingLine = line
        }
    }

    private func preparationLine(
        agentID: String,
        bubbleKey: String
    ) -> MeetingLine {
        let bubble = AppLanguage.localized(bubbleKey)
        return MeetingLine(
            stage: meetingStage(for: agentID),
            agentId: agentID,
            bubble: bubble,
            log: bubble
        )
    }

    private func replayMeeting(_ result: AnalysisPayload) async {
        let huddles = preCouncilHuddles(in: result)
        isPreCouncil = !huddles.isEmpty
        for (index, huddle) in huddles.enumerated() {
            guard !Task.isCancelled, !didRequestMeetingSkip else { return }
            await replayHuddle(huddle, returnsToStations: index < huddles.count - 1)
        }

        guard !Task.isCancelled, !didRequestMeetingSkip else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            hasCompletedSmallGroupDiscussion = true
        }
        do {
            try await Task.sleep(for: .seconds(AnalysisMeetingPacing.preCouncilSkipLeadTime))
        } catch {
            return
        }
        guard !Task.isCancelled, !didRequestMeetingSkip else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            councilHuddle = nil
            isPreCouncil = false
            isFullCouncilRound = false
            meetingOriginHuddleParticipants = huddles.last?.participants ?? []
            meetingStartedAt = Date()
            hasMeetingReplayStarted = true
            stage = .gathering
            workingLine = nil
            activeLine = nil
        }
        do { try await Task.sleep(for: .seconds(meetingDuration)) } catch { return }
        guard !Task.isCancelled, !didRequestMeetingSkip else { return }

        let councilLines = fullCouncilLines(
            result: result,
            excluding: Set(huddles.flatMap(\.lines).map(\.id))
        )
        withAnimation(.easeInOut(duration: 0.22)) { isFullCouncilRound = true }
        for line in councilLines {
            guard !Task.isCancelled, !didRequestMeetingSkip else { return }
            activeLine = nil
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            guard !didRequestMeetingSkip else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                stage = stageForMeetingLine(line)
                activeLine = line
            }
            do { try await Task.sleep(for: .seconds(councilLineDuration)) } catch { return }
        }

        guard !didRequestMeetingSkip else { return }

        activeLine = nil
        do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
        isFullCouncilRound = false
        hasMeetingReplayStarted = false
        withAnimation(.easeInOut(duration: 0.30)) { stage = .complete }
        do { try await Task.sleep(for: .seconds(1.1)) } catch { return }
        withAnimation(.easeInOut(duration: 0.22)) { isResultVisible = true }
    }

    private func replayHuddle(_ huddle: CouncilHuddleRound, returnsToStations: Bool) async {
        guard huddle.participants.count >= 2, huddle.lines.count >= 2 else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stage = stageForMeetingLine(huddle.lines[0])
            workingLine = nil
            activeLine = nil
            councilHuddle = CouncilHuddle(
                startedAt: Date(),
                duration: huddleDuration,
                participants: huddle.participants,
                returnsToStations: returnsToStations
            )
        }

        do { try await Task.sleep(for: .seconds(AnalysisMeetingPacing.huddleArrivalDelay)) } catch { return }
        for line in huddle.lines.prefix(2) {
            withTransaction(transaction) {
                stage = stageForMeetingLine(line)
                activeLine = line
            }
            do { try await Task.sleep(for: .seconds(huddleLineDuration)) } catch { return }
            withTransaction(transaction) { activeLine = nil }
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
        }
        if returnsToStations {
            do {
                try await Task.sleep(for: .seconds(AnalysisMeetingPacing.huddleReturnSettleDuration))
            } catch {
                return
            }
            withTransaction(transaction) { councilHuddle = nil }
        } else {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
        }
    }

    private func preCouncilHuddles(in result: AnalysisPayload) -> [CouncilHuddleRound] {
        let lines = result.meetingScript
        let seedIndices = preCouncilHuddleSeedIndices(in: lines)
        let reservedSeedIDs = Set(seedIndices.compactMap { lines.indices.contains($0) ? lines[$0].id : nil })
        var consumedLineIDs = Set<String>()

        return seedIndices.compactMap { index in
            guard lines.indices.contains(index) else { return nil }
            let seed = lines[index]
            guard !consumedLineIDs.contains(seed.id) else { return nil }
            let participants = discussionGroup(for: seed)
            guard participants.count >= 2 else { return nil }
            let participantIDs = Set(participants.map { PixelAgent.team[$0].id })
            consumedLineIDs.insert(seed.id)

            let response = lines.first {
                participantIDs.contains($0.agentId)
                    && $0.agentId != seed.agentId
                    && !consumedLineIDs.contains($0.id)
                    && !reservedSeedIDs.contains($0.id)
            } ?? syntheticResponse(
                to: seed,
                participantIDs: participantIDs,
                result: result
            ) ?? fallbackHuddleResponse(to: seed, participantIDs: participantIDs)
            guard let response else { return nil }
            consumedLineIDs.insert(response.id)
            return CouncilHuddleRound(lines: [seed, response], participants: participants)
        }
    }

    private func preCouncilHuddleSeedIndices(in lines: [MeetingLine]) -> [Int] {
        let maximum = min(2, max(0, lines.count - 1))
        guard maximum > 0 else { return [] }

        var selected: [Int] = []
        if let pair = lines.indices.first(where: { discussionGroup(for: lines[$0]).count == 2 }) {
            selected.append(pair)
        }
        if selected.count < maximum,
           let trio = lines.indices.first(where: { !selected.contains($0) && discussionGroup(for: lines[$0]).count >= 3 }) {
            selected.append(trio)
        }
        for index in lines.indices where selected.count < maximum && !selected.contains(index) {
            selected.append(index)
        }
        return selected
    }

    private func syntheticResponse(
        to seed: MeetingLine,
        participantIDs: Set<String>,
        result: AnalysisPayload
    ) -> MeetingLine? {
        guard let opinion = result.agentOpinions.first(where: {
            participantIDs.contains($0.agentId) && $0.agentId != seed.agentId
        }) else { return nil }
        let thesis = opinion.thesis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thesis.isEmpty else { return nil }
        return MeetingLine(
            stage: meetingStage(for: opinion.agentId),
            agentId: opinion.agentId,
            bubble: thesis,
            log: thesis
        )
    }

    private func fallbackHuddleResponse(
        to seed: MeetingLine,
        participantIDs: Set<String>
    ) -> MeetingLine? {
        guard let responderID = PixelAgent.team.map(\.id).first(where: {
            participantIDs.contains($0) && $0 != seed.agentId
        }) else { return nil }
        return AnalysisMockDialogues.randomLine(for: responderID)
    }

    private func fullCouncilLines(
        result: AnalysisPayload,
        excluding excludedLineIDs: Set<String>
    ) -> [MeetingLine] {
        let activeIDs = PixelAgent.team.map(\.id).filter(draft.activeAgentIDs.contains)

        return activeIDs.compactMap { agentID in
            if let unusedLine = result.meetingScript.first(where: {
                $0.agentId == agentID && !excludedLineIDs.contains($0.id)
            }) {
                return unusedLine
            }
            guard let opinion = result.agentOpinions.first(where: { $0.agentId == agentID }) else {
                return result.meetingScript.first(where: { $0.agentId == agentID })
                    ?? AnalysisMockDialogues.randomLine(for: agentID)
            }
            let thesis = opinion.thesis.trimmingCharacters(in: .whitespacesAndNewlines)
            return MeetingLine(
                stage: meetingStage(for: agentID),
                agentId: agentID,
                bubble: thesis,
                log: thesis
            )
        }
    }

    private func meetingStage(for agentID: String) -> String {
        switch agentID {
        case "trend": "trend"
        case "pattern": "pattern"
        case "momentum": "momentum"
        case "risk": "risk"
        default: "dissent"
        }
    }

    private func skipToResult() {
        guard isCouncilSkipAvailable else { return }
        didRequestMeetingSkip = true
        activeLine = nil
        workingLine = nil
        isFullCouncilRound = false
        hasMeetingReplayStarted = false
        stage = .complete
        withAnimation(.easeInOut(duration: 0.22)) {
            isResultVisible = true
        }
    }

    private func stageForMeetingLine(_ line: MeetingLine) -> AnalysisStage {
        switch line.stage {
        case "trend", "pattern": .debateTrend
        case "momentum", "risk", "debate": .debateMomentum
        case "dissent": .dissent
        default: .synthesis
        }
    }
}

private struct MeetingTranscriptEntry: Identifiable {
    let id = UUID()
    let line: MeetingLine
}

private struct MeetingTranscriptRow: View {
    let entry: MeetingTranscriptEntry
    let visibleStatement: String?
    let isTyping: Bool

    private var agent: PixelAgent {
        PixelAgent.team.first(where: { $0.id == entry.line.agentId }) ?? PixelAgent.defaultTeam[0]
    }

    private var statement: String {
        AnalysisMeetingDialogue.visibleBubble(for: entry.line)
    }

    private var displayedStatement: String {
        visibleStatement ?? statement
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            PixelAgentView(
                agent: agent,
                direction: .front,
                pose: .reading,
                phase: 0,
                scale: 0.58,
                scaleAnchor: .center
            )
            .frame(width: 40, height: 44)
            .background(agent.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(agent.localizedName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(agent.localizedRole)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(agent.accent)
                }
                ZStack(alignment: .topLeading) {
                    Text(statement)
                        .hidden()
                        .accessibilityHidden(true)
                    Text(displayedStatement + (isTyping ? "▌" : ""))
                        .foregroundStyle(.white.opacity(0.90))
                }
                .font(.system(size: 14, weight: .bold))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

enum AnalysisMeetingDialogue {
    static func visibleBubble(for line: MeetingLine) -> String {
        let bubble = line.bubble.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = line.log.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = bubble.count < 12 && log.count > bubble.count ? log : bubble
        return removingSpeakerPrefix(from: selected, agentID: line.agentId)
    }

    private static func removingSpeakerPrefix(from text: String, agentID: String) -> String {
        let matchingAgents = (PixelAgent.team + PixelAgent.defaultTeam)
            .filter { $0.id == agentID }
        let names = Set(
            matchingAgents.flatMap { [$0.name, $0.localizedName] }
                + [agentID]
        )

        for separator in [": ", ":", " · "] {
            guard let range = text.range(of: separator) else { continue }
            let candidate = String(text[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard names.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) else {
                continue
            }
            return String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}

struct AnalysisSessionHeaderTitle: View {
    let contextLabel: String

    var body: some View {
        VStack(spacing: 2) {
            Text("LIVE RESEARCH ROOM")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(ChartTheme.mint)
            Text(contextLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChartTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .frame(height: 16)
        }
    }
}

private struct CouncilHuddle {
    let startedAt: Date
    let duration: TimeInterval
    let participants: [Int]
    let returnsToStations: Bool
}

private struct CouncilHuddleRound {
    let lines: [MeetingLine]
    let participants: [Int]
}
