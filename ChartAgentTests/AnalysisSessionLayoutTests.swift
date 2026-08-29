import SwiftUI
import XCTest
@testable import ChartAgent

@MainActor
final class AnalysisSessionLayoutTests: XCTestCase {
    func testScrollReporterUpdatesSharedTabBarStateAtTheSource() throws {
        let source = try sourceText(at: "ChartAgent/Main/MainTabView.swift")

        XCTAssertTrue(source.contains("@Environment(MainTabBarScrollState.self)"))
        XCTAssertTrue(source.contains("tabBarState.update(offset:"))
        XCTAssertFalse(
            source.contains(".onPreferenceChange(MainScrollOffsetPreferenceKey.self, perform: updateTabBar)"),
            "A root preference observer is unreliable across the selected-screen and List boundaries"
        )
    }

    func testExpandedBottomNavigationUsesReducedHeightAndLowerInset() throws {
        let source = try sourceText(at: "ChartAgent/Main/MainTabView.swift")

        XCTAssertTrue(source.contains("height: isCompact ? 34 : 40"))
        XCTAssertTrue(source.contains(".padding(.bottom, 0)"))
        XCTAssertTrue(source.contains(".padding(.vertical, isCompact ? 4 : 5)"))
        XCTAssertTrue(source.contains(".offset(y: 5)"))
    }

    func testScrollDirectionCompactsAndExpandsBottomNavigation() {
        let state = MainTabBarScrollState()

        state.update(offset: 0)
        state.update(offset: -7)
        state.update(offset: -15)
        XCTAssertTrue(state.isCompact)

        state.update(offset: -8)
        state.update(offset: 2)
        XCTAssertFalse(state.isCompact)
    }

    func testFastScrollJumpStillCompactsBottomNavigation() {
        let state = MainTabBarScrollState()

        state.update(offset: 0)
        state.update(offset: -180)

        XCTAssertTrue(state.isCompact)
    }

    func testBottomNavigationNeverRendersVisibleTitles() throws {
        let source = try sourceText(at: "ChartAgent/Main/MainTabView.swift")

        XCTAssertFalse(
            source.contains("Text(tab.title)"),
            "Bottom navigation should remain icon-only in both expanded and compact states"
        )
    }

    func testHomeDoesNotShowConsumedFreeAnalysisCaption() throws {
        let source = try sourceText(at: "ChartAgent/Main/HomeView.swift")

        XCTAssertFalse(
            source.contains("무료 분석 1회를 사용했습니다. 기존 결과는 계속 확인할 수 있어요."),
            "The home screen should not display the consumed-free-analysis caption"
        )
    }

    func testRunningAnalysisCoordinatorIsOwnedByTheApp() throws {
        let appSource = try sourceText(at: "ChartAgent/App/ChartAgentApp.swift")
        let uploadSource = try sourceText(at: "ChartAgent/Analysis/AnalysisUploadView.swift")

        XCTAssertTrue(
            appSource.contains("@StateObject private var analysisRunCoordinator = AnalysisRunCoordinator()"),
            "The analysis task must outlive the transient upload sheet"
        )
        XCTAssertTrue(
            uploadSource.contains("@EnvironmentObject private var runCoordinator: AnalysisRunCoordinator"),
            "A recreated upload screen must reattach to the app-scoped analysis task"
        )
        XCTAssertFalse(
            uploadSource.contains("@StateObject private var runCoordinator = AnalysisRunCoordinator()"),
            "The upload sheet must not own and destroy the active analysis task"
        )
    }

    func testImageSourceChooserIsPresentedAsBottomSheet() throws {
        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisUploadView.swift")

        XCTAssertTrue(source.contains("ImageSourceChoiceSheet("))
        XCTAssertTrue(source.contains(".presentationDetents([.height(220)])"))
        XCTAssertFalse(
            source.contains(".confirmationDialog("),
            "The source chooser should use a deterministic bottom sheet on iPhone"
        )
    }

    func testClosingCompletedAnalysisClearsTheSelectedImage() throws {
        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisUploadView.swift")

        XCTAssertTrue(source.contains("clearSelectedImage()"))
        XCTAssertTrue(source.contains("selectedImageData = nil"))
        XCTAssertTrue(source.contains("sourceImage = nil"))
    }

    func testAgentRosterLocalizesPersistedDefaultTone() throws {
        let source = try sourceText(at: "ChartAgent/Main/AgentStudioView.swift")

        XCTAssertTrue(
            source.contains("profileStore.profile(for: agent.id)?.localizedTone ?? \"\""),
            "Persisted default tone keys must be resolved in the active app language"
        )
    }

    func testAgentRosterCentersScaledSprites() throws {
        let source = try sourceText(at: "ChartAgent/Main/AgentStudioView.swift")

        XCTAssertTrue(
            source.contains("scaleAnchor: .center"),
            "Roster sprites must scale around their center rather than their feet"
        )
    }

    func testHeaderHeightDoesNotChangeWhenDetectedSymbolArrives() {
        let detecting = renderedHeight(
            AnalysisSessionHeaderTitle(contextLabel: "심볼·시간대 자동 판독 · 5 AGENTS")
        )
        let detected = renderedHeight(
            AnalysisSessionHeaderTitle(contextLabel: "BTCUSD · 4H · 5 AGENTS")
        )

        XCTAssertEqual(detecting, detected, accuracy: 0.5)
    }

    func testEveryAgentHasTenDistinctPreparationLines() {
        for agentID in AnalysisMockDialogues.agentIDs {
            let lines = AnalysisMockDialogues.lines(for: agentID)
            XCTAssertEqual(lines.count, 10, "\(agentID) should have ten mock lines")
            XCTAssertEqual(Set(lines.map(\.bubble)).count, 10, "\(agentID) lines should be distinct")
        }
    }

    func testPreparationAddsOneCompleteMockDialogueRound() {
        let lines = AnalysisMeetingPacing.mockPreparationRound(
            activeAgentIDs: ["momentum", "trend", "devil", "pattern", "risk"]
        )

        XCTAssertEqual(lines.map(\.agentId), AnalysisMockDialogues.agentIDs)
        XCTAssertEqual(Set(lines.map(\.agentId)).count, 5)
    }

    func testPreparationMockLinesNeverActivateCrossCheckRail() {
        for agentID in AnalysisMockDialogues.agentIDs {
            let stage = AnalysisMeetingPacing.preparationStage(for: agentID)
            XCTAssertFalse(stage.isMeeting, "\(agentID) must stay in preparation before replay starts")
            XCTAssertLessThanOrEqual(stage.rawValue, AnalysisStage.risk.rawValue)
        }
    }

    func testWaitingMockDialogueNeverMovesPreparationProgressBackward() {
        let candidates = ["trend", "pattern", "momentum", "risk", "devil", "trend"]
            .map(AnalysisMeetingPacing.preparationStage(for:))
        let rendered = candidates.reduce(into: [AnalysisStage.scanning]) { stages, candidate in
            stages.append(
                AnalysisMeetingPacing.nonRegressingPreparationStage(
                    current: stages.last!,
                    candidate: candidate
                )
            )
        }

        XCTAssertEqual(rendered.map(\.rawValue), rendered.map(\.rawValue).sorted())
        XCTAssertEqual(rendered.last, .risk)
    }

    func testMockRoundStartsThreeSecondsAfterPreparationRound() {
        XCTAssertEqual(AnalysisMeetingPacing.mockRoundLeadTime, 3.0, accuracy: 0.01)
    }

    func testResponseWaitingBubbleBelongsToDevil() {
        XCTAssertEqual(AnalysisMeetingPacing.responseWaitingAgentID, "devil")
        XCTAssertEqual(AnalysisMeetingPacing.responseWaitingBubbleKey, "에이전트를 기다리고 있습니다…")
    }

    func testWaitingCopySwitchesToConceptWorkAfterFiveSeconds() {
        XCTAssertEqual(AnalysisMeetingPacing.responseConceptLeadTime, 5.0, accuracy: 0.01)
        XCTAssertGreaterThan(AnalysisMeetingPacing.responseConceptLineDuration, 2.0)
    }

    func testEveryInvestmentConceptHasDistinctLocalizedWaitingCopy() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        AppLanguage.select(.korean)
        defer {
            if let previous {
                AppLanguage.select(rawValue: previous)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        let lines = InvestmentConcept.allCases.map(AgentConceptMockCopy.responseWaitingRemark)
        XCTAssertEqual(lines.count, 20)
        XCTAssertEqual(Set(lines).count, 20)
        XCTAssertTrue(lines.allSatisfy { $0.hasSuffix("중…") })
    }

    func testConnectionBubbleUsesContentWidthInsteadOfLegacyMinimum() {
        let koreanWidth = OfficeBubbleLayout.width(
            text: "연결 완료",
            showsCursor: true,
            maximum: 220
        )
        let longerWidth = OfficeBubbleLayout.width(
            text: "Verbindung hergestellt",
            showsCursor: true,
            maximum: 220
        )

        XCTAssertLessThan(koreanWidth, 92)
        XCTAssertGreaterThan(longerWidth, koreanWidth)
    }

    func testFailureKindsRemainVisuallyAndSemanticallyDistinct() {
        XCTAssertEqual(
            ChartAgentAPIError.server(.init(code: "not_chart", message: "", recovery: nil)).failureKind,
            .invalidChart
        )
        XCTAssertEqual(
            ChartAgentAPIError.server(.init(code: "analysis_unavailable", message: "", recovery: nil)).failureKind,
            .aiResponse
        )
        XCTAssertEqual(
            ChartAgentAPIError.server(.init(code: "internal_error", message: "", recovery: nil)).failureKind,
            .server
        )
        XCTAssertEqual(ChartAgentAPIError.transport("offline").failureKind, .network)
        XCTAssertEqual(ChartAgentAPIError.invalidResponse.failureKind, .malformedResponse)
    }

    func testConnectionRoundIsLocalizedAndVisualOnly() throws {
        XCTAssertEqual(AnalysisMeetingPacing.connectionBubbleKey, "연결 완료")
        XCTAssertGreaterThanOrEqual(AnalysisMeetingPacing.connectionLineDuration, 0.6)

        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisSessionView.swift")
        XCTAssertTrue(source.contains("connectionAgentID"))
        XCTAssertTrue(source.contains("await showConnectionRound()"))
        XCTAssertTrue(source.contains(".onChange(of: displayedLine)"))
        XCTAssertFalse(source.contains(".onChange(of: connectionAgentID)"))
    }

    func testResearchOfficeAllowsAgentInspection() throws {
        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisSessionView.swift")
        XCTAssertTrue(source.contains("selectedAgentID: $selectedAgentID"))
    }

    func testResultHeaderDropsExchangePrefix() throws {
        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisResultView.swift")
        XCTAssertTrue(source.contains("MarketLanguage.symbolLabel(record.symbol)"))
        XCTAssertFalse(source.contains("Text(\"\\(record.symbol.code) · "))
    }

    func testRunningAnalysisHeaderDropsExchangePrefix() throws {
        let source = try sourceText(at: "ChartAgent/Analysis/AnalysisSessionView.swift")
        XCTAssertTrue(source.contains("MarketLanguage.symbolLabel(record.symbol)"))
        XCTAssertFalse(source.contains("return \"\\(record.symbol.code) · "))
    }

    func testProfileCardOpensEditableBottomSheet() throws {
        let source = try sourceText(at: "ChartAgent/Main/SecondaryScreens.swift")
        XCTAssertTrue(source.contains("isProfileEditorPresented = true"))
        XCTAssertTrue(source.contains("ProfileEditorSheet()"))
        XCTAssertTrue(source.contains("storedExperience = draftExperience.rawValue"))
    }

    func testAnalysisRequestTimeoutIsTwoMinutes() {
        XCTAssertEqual(AnalysisRequestTiming.maximumDuration, 120, accuracy: 0.01)
    }

    func testSmallGroupArrivalIsFasterWithoutBecomingAbrupt() {
        XCTAssertGreaterThanOrEqual(AnalysisMeetingPacing.huddleArrivalDelay, 2.2)
        XCTAssertLessThanOrEqual(AnalysisMeetingPacing.huddleArrivalDelay, 3.0)
    }

    func testPreparationKeepsAgentsAtStationsUntilReplayActuallyStarts() {
        XCTAssertFalse(
            AnalysisMeetingPacing.shouldRenderMeetingLayout(
                replayStarted: false,
                stageIsMeeting: true
            )
        )
        XCTAssertTrue(
            AnalysisMeetingPacing.shouldRenderMeetingLayout(
                replayStarted: true,
                stageIsMeeting: true
            )
        )
    }

    func testCouncilSkipIsOfferedAfterSmallGroupDiscussionBeforeGathering() {
        XCTAssertFalse(
            AnalysisMeetingPacing.shouldOfferSkip(
                hasResult: false,
                completedSmallGroupDiscussion: true
            )
        )
        XCTAssertFalse(
            AnalysisMeetingPacing.shouldOfferSkip(
                hasResult: true,
                completedSmallGroupDiscussion: false
            )
        )
        XCTAssertTrue(
            AnalysisMeetingPacing.shouldOfferSkip(
                hasResult: true,
                completedSmallGroupDiscussion: true
            )
        )
    }

    func testCouncilGatheringIsSlightlyFasterWithoutBecomingAbrupt() {
        XCTAssertGreaterThanOrEqual(AnalysisMeetingPacing.meetingDuration, 3.2)
        XCTAssertLessThan(AnalysisMeetingPacing.meetingDuration, 4.0)
        XCTAssertGreaterThanOrEqual(AnalysisMeetingPacing.preCouncilSkipLeadTime, 0.2)
        XCTAssertLessThanOrEqual(AnalysisMeetingPacing.preCouncilSkipLeadTime, 0.5)
    }

    func testActualResponseFragmentFallsBackToCompleteLog() {
        let line = MeetingLine(
            stage: "synthesis",
            agentId: "trend",
            bubble: "최종 판단",
            log: "현재 구간은 확인선 회복 전까지 매도 우위로 판단하며, 돌파가 나오면 관점을 다시 검토한다."
        )

        XCTAssertEqual(AnalysisMeetingDialogue.visibleBubble(for: line), line.log)
    }

    func testLongestResponseFinishesTypingInsideHuddleWindow() {
        let duration = OfficeBubbleTypingPolicy.totalTypingDuration(
            characterCount: 100,
            budget: 0.72
        )

        XCTAssertLessThanOrEqual(duration, 0.72)
    }

    func testActiveEntitlementDoesNotDismissPaywallDuringPriceLoad() {
        XCTAssertFalse(
            ProPaywallTransitionPolicy.shouldCompleteAfterLoad(isProActive: true),
            "Loading RevenueCat prices must never dismiss the onboarding paywall by itself"
        )
    }

    func testAnalysisResultWaitsForEntitlementResolution() {
        XCTAssertEqual(
            AnalysisResultAccessPolicy.access(isEntitlementResolved: false, isProActive: false),
            .checking
        )
    }

    func testAnalysisResultIsLockedForNonSubscriber() {
        XCTAssertEqual(
            AnalysisResultAccessPolicy.access(isEntitlementResolved: true, isProActive: false),
            .locked
        )
    }

    func testAnalysisResultIsUnlockedForSubscriber() {
        XCTAssertEqual(
            AnalysisResultAccessPolicy.access(isEntitlementResolved: true, isProActive: true),
            .unlocked
        )
    }

    func testFirstAnalysisIsAvailableToNonSubscriber() {
        XCTAssertEqual(
            AnalysisStartAccessPolicy.access(
                isEntitlementResolved: true,
                hasProAccess: false,
                hasUsedFreeAnalysis: false
            ),
            .available
        )
    }

    func testNonSubscriberCannotStartSecondAnalysis() {
        XCTAssertEqual(
            AnalysisStartAccessPolicy.access(
                isEntitlementResolved: true,
                hasProAccess: false,
                hasUsedFreeAnalysis: true
            ),
            .locked
        )
    }

    func testDescriptiveTradeLevelDoesNotDisappearWhenItHasNoNumber() {
        XCTAssertEqual(
            TradePriceLevelFormatter.displayValue(from: "지지 재확인 후 진입"),
            "지지 재확인 후 진입"
        )
    }

    func testNumericTradeLevelStaysCompact() {
        XCTAssertEqual(
            TradePriceLevelFormatter.displayValue(from: "64,390 ~ 65,600 반등 구간"),
            "64,390–65,600"
        )
    }

    func testNonSubscriberProfileStatusDoesNotDuplicatePlanCTA() throws {
        let source = try sourceText(at: "ChartAgent/Main/SecondaryScreens.swift")

        XCTAssertTrue(
            source.contains("subscriptionStore.isProActive ? \"ChartAgent PRO 활성\" : \"무료 이용 중\"")
        )
    }

    func testLockedHomeCTAOpensPaywallInsteadOfIgnoringTap() throws {
        let source = try sourceText(at: "ChartAgent/Main/HomeView.swift")

        XCTAssertTrue(source.contains("case .locked:\n                isPaywallPresented = true"))
        XCTAssertTrue(source.contains(".disabled(analysisStartAccess == .checking)"))
        XCTAssertTrue(source.contains(".fullScreenCover(isPresented: $isPaywallPresented)"))
    }

    func testSubscriberCanAlwaysStartAnotherAnalysis() {
        XCTAssertEqual(
            AnalysisStartAccessPolicy.access(
                isEntitlementResolved: true,
                hasProAccess: true,
                hasUsedFreeAnalysis: true
            ),
            .available
        )
    }

    func testLastOnboardingContentPageAdvancesToPaywall() {
        XCTAssertEqual(
            OnboardingPageSequence.nextPage(after: OnboardingPageSequence.lastContentPage),
            OnboardingPageSequence.paywallPage
        )
    }

    func testConsentDisclosureIsTheFinalOnboardingContentPage() throws {
        XCTAssertEqual(OnboardingPageSequence.lastContentPage, 12)
        XCTAssertEqual(OnboardingPageSequence.paywallPage, 13)

        let source = try sourceText(at: "ChartAgent/Onboarding/OnboardingFlow.swift")
        XCTAssertTrue(source.contains("ConsentOnboarding"))
        XCTAssertTrue(source.contains("hasAcceptedTerms"))
    }

    func testEveryInvestmentConceptDrivesLocalizedHomeAndAnalysisMockCopy() {
        for concept in InvestmentConcept.allCases {
            XCTAssertFalse(AgentConceptMockCopy.homeRemark(for: concept).isEmpty, concept.rawValue)
            XCTAssertFalse(
                AgentConceptMockCopy.analysisRemark(for: concept, stage: .evidence).isEmpty,
                concept.rawValue
            )
        }
    }

    func testOnboardingCTAUsesHighContrastBeam() {
        XCTAssertTrue(OnboardingCTAVisualPolicy.usesHighContrastBeam)
    }

    func testVerboseServerStanceIsReducedToOneWord() {
        XCTAssertEqual(MarketLanguage.normalizedStanceCode("매도 우위 - 4H 하락 압력"), "bearish")
        XCTAssertTrue(["매도", "SELL"].contains(MarketLanguage.stanceLabel("매도 우위 - 4H 하락 압력")))
    }

    private func renderedHeight<Content: View>(_ content: Content) -> CGFloat {
        let controller = UIHostingController(rootView: content.frame(width: 150))
        return controller.sizeThatFits(in: CGSize(width: 150, height: 200)).height
    }

    private func sourceText(at relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
