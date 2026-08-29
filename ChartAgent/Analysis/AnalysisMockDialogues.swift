import Foundation

enum AnalysisMockDialogues {
    static let agentIDs = ["trend", "pattern", "momentum", "risk", "devil"]

    private static let preparationStages: [AnalysisStage] = [
        .scanning,
        .evidence,
        .trend,
        .pattern,
        .momentum,
        .risk,
        .debateTrend,
        .debateMomentum,
        .dissent,
        .synthesis
    ]

    static func lines(for agentID: String) -> [MeetingLine] {
        let agent = PixelAgent.team.first(where: { $0.id == agentID })
            ?? PixelAgent.defaultTeam.first(where: { $0.id == agentID })
            ?? PixelAgent.defaultTeam[0]

        return preparationStages.map { preparationStage in
            let concept = AgentConceptMockCopy.concept(for: agentID)
            return MeetingLine(
                stage: meetingStage(for: agentID),
                agentId: agentID,
                bubble: AgentConceptMockCopy.analysisRemark(for: concept, stage: preparationStage),
                log: "\(agent.localizedName) · \(preparationStage.detail)"
            )
        }
    }

    static func randomLine(for agentID: String, excludingBubble: String? = nil) -> MeetingLine {
        let pool = lines(for: agentID)
        let alternatives = pool.filter { $0.bubble != excludingBubble }
        return alternatives.randomElement() ?? pool.randomElement()!
    }

    private static func meetingStage(for agentID: String) -> String {
        switch agentID {
        case "pattern": "pattern"
        case "momentum": "momentum"
        case "risk": "risk"
        case "devil": "dissent"
        default: "trend"
        }
    }
}

enum AnalysisMeetingPacing {
    static let connectionBubbleKey = "연결 완료"
    static let connectionLineDuration: TimeInterval = 0.72
    static let meetingDuration: TimeInterval = 3.4
    static let preCouncilSkipLeadTime: TimeInterval = 0.30
    static let huddleDuration: TimeInterval = 8.6
    static let huddleLineDuration: TimeInterval = 2.30
    static let councilLineDuration: TimeInterval = 3.25
    static let mockPreparationLineDuration: TimeInterval = 2.65
    static let mockRoundLeadTime: TimeInterval = 3.0
    static let responseWaitPollInterval: TimeInterval = 0.5
    static let responseConceptLeadTime: TimeInterval = 5.0
    static let responseConceptLineDuration: TimeInterval = 3.2
    static let responseWaitingAgentID = "devil"
    static let responseWaitingBubbleKey = "에이전트를 기다리고 있습니다…"
    static let huddleReturnSettleDuration: TimeInterval = 0.95

    static let huddleDepartureProgress: CGFloat = 0.08
    static let huddleWalkStartProgress: CGFloat = 0.11
    static let huddleArrivalProgress: CGFloat = 0.30
    static let huddleReturnStartProgress: CGFloat = 0.88
    static let huddleReturnEndProgress: CGFloat = 0.97
    static let huddleSitProgress: CGFloat = 0.99

    static func preparationStage(for agentID: String) -> AnalysisStage {
        switch agentID {
        case "trend": .trend
        case "pattern": .pattern
        case "momentum": .momentum
        case "risk", "devil": .risk
        default: .evidence
        }
    }

    static func nonRegressingPreparationStage(
        current: AnalysisStage,
        candidate: AnalysisStage
    ) -> AnalysisStage {
        candidate.rawValue < current.rawValue ? current : candidate
    }

    static var huddleArrivalDelay: TimeInterval {
        huddleDuration * TimeInterval(huddleArrivalProgress)
    }

    static func mockPreparationRound(activeAgentIDs: [String]) -> [MeetingLine] {
        let activeIDs = Set(activeAgentIDs)
        return AnalysisMockDialogues.agentIDs
            .filter(activeIDs.contains)
            .map { AnalysisMockDialogues.randomLine(for: $0) }
    }

    static func shouldRenderMeetingLayout(
        replayStarted: Bool,
        stageIsMeeting: Bool
    ) -> Bool {
        replayStarted && stageIsMeeting
    }

    static func shouldOfferSkip(
        hasResult: Bool,
        completedSmallGroupDiscussion: Bool
    ) -> Bool {
        hasResult && completedSmallGroupDiscussion
    }
}
