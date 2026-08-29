import SwiftUI
import UIKit

enum PixelOfficeMode {
    case office
    case meeting(progress: CGFloat)
    case liveMeeting(startedAt: Date, duration: TimeInterval)
    case liveMeetingFromHuddle(startedAt: Date, duration: TimeInterval, participants: [Int])
    case liveHuddle(startedAt: Date, duration: TimeInterval, participants: [Int], returnsToStations: Bool)
}

struct PixelOfficeView: View {
    var focusedAgentIndex: Int?
    var bubbleText: String?
    var mode: PixelOfficeMode = .office
    var isAnalyzing = false
    var isAutonomous = false
    var showsMeetingTable = false
    var height: CGFloat = 520
    var activeAgentIDs: Set<String> = Set(PixelAgent.team.map(\.id))
    var discussionAgentIndices: [Int] = []
    var selectedAgentID: Binding<String?>? = nil
    var onBubbleTypingUpdate: ((OfficeBubbleTypingUpdate) -> Void)? = nil
    var bubbleTypingBudget: TimeInterval = 0.72

    @State private var activeBubble: OfficeBubbleEvent?
    @State private var typedBubble = ""
    @State private var isBubbleTyping = false

    private var bubbleRequest: OfficeBubbleEvent? {
        guard let focusedAgentIndex,
              PixelAgent.team.indices.contains(focusedAgentIndex),
              let bubbleText,
              !bubbleText.isEmpty else { return nil }
        return OfficeBubbleEvent(speakerIndex: focusedAgentIndex, text: bubbleText)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OfficeFurnitureLayer(showsMeetingTable: showsMeetingTable || meetingModeIsActive)

                TimelineView(.animation(minimumInterval: 1 / 30, paused: !needsContinuousMotion)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let meetingProgress = meetingProgress(at: timeline.date)
                    ZStack {
                        if let meetingProgress {
                            MeetingEvidenceLayer(progress: meetingProgress, activeAgentIDs: activeAgentIDs)
                        }

                        ForEach(Array(PixelAgent.team.enumerated()), id: \.element.id) { index, agent in
                            if activeAgentIDs.contains(agent.id) {
                                let state = renderState(index: index, time: now, size: proxy.size, meetingProgress: meetingProgress)
                                ZStack {
                                    Button {
                                        selectedAgentID?.wrappedValue = agent.id
                                    } label: {
                                        PixelAgentView(
                                            agent: agent,
                                            direction: state.direction,
                                            pose: state.pose,
                                            phase: now + Double(index) * 0.31,
                                            scale: 0.90,
                                            showsName: true,
                                            isSelected: selectedAgentID?.wrappedValue == agent.id
                                        )
                                        .frame(width: 76, height: 86)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .position(state.point)
                                .transaction { transaction in transaction.animation = nil }
                                .zIndex(100 + state.point.y)
                            }
                        }

                        if let activeBubble,
                           !typedBubble.isEmpty,
                           bubbleCanAppear(at: timeline.date, meetingProgress: meetingProgress) {
                            let state = renderState(
                                index: activeBubble.speakerIndex,
                                time: now,
                                size: proxy.size,
                                meetingProgress: meetingProgress
                            )
                            let head = CGPoint(x: state.point.x, y: state.point.y - 34)
                            HeadAnchoredBubble(
                                text: typedBubble,
                                showsCursor: isBubbleTyping,
                                speakerHead: head,
                                availableSize: proxy.size
                            )
                            .id(activeBubble)
                            .transaction { transaction in transaction.animation = nil }
                            .zIndex(900)
                        } else if let remark = ambientRemark(at: now) {
                            let state = renderState(
                                index: remark.speakerIndex,
                                time: now,
                                size: proxy.size,
                                meetingProgress: nil
                            )
                            let head = CGPoint(x: state.point.x, y: state.point.y - 34)
                            HeadAnchoredBubble(
                                text: remark.text,
                                showsCursor: false,
                                speakerHead: head,
                                availableSize: proxy.size
                            )
                            .transaction { transaction in transaction.animation = nil }
                            .zIndex(900)
                        }

                        if let selectedID = selectedAgentID?.wrappedValue,
                           let selected = PixelAgent.team.first(where: { $0.id == selectedID }) {
                            MinimalAgentPanel(agent: selected) {
                                selectedAgentID?.wrappedValue = nil
                            }
                            .padding(12)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(1_000)
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OfficePalette.frame, lineWidth: 3)
        }
        .task(id: bubbleRequest) {
            await replaceBubble(with: bubbleRequest)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: selectedAgentID?.wrappedValue)
    }

    private var needsContinuousMotion: Bool {
        switch mode {
        case .meeting(let progress): progress > 0.01 && progress < 0.99
        case .liveMeeting, .liveMeetingFromHuddle, .liveHuddle: true
        case .office: isAutonomous
        }
    }

    private var meetingModeIsActive: Bool {
        switch mode {
        case .office: false
        case .meeting, .liveMeeting, .liveMeetingFromHuddle: true
        case .liveHuddle: false
        }
    }

    private func ambientRemark(at time: Double) -> OfficeAmbientRemark? {
        guard isAutonomous,
              !isAnalyzing,
              activeBubble == nil,
              selectedAgentID?.wrappedValue == nil else { return nil }

        let interval = 24.0
        let phase = time.truncatingRemainder(dividingBy: interval)
        guard phase >= 14.2, phase < 17.2 else { return nil }

        let cycle = Int(floor(time / interval))
        let order = [0, 2, 3, 1, 4]
        let speaker = order[((cycle % order.count) + order.count) % order.count]
        let agentID = PixelAgent.team[speaker].id
        let concept = AgentConceptMockCopy.concept(for: agentID)
        let text = AgentConceptMockCopy.homeRemark(for: concept)
        return OfficeAmbientRemark(speakerIndex: speaker, text: text)
    }

    private func meetingProgress(at date: Date) -> CGFloat? {
        switch mode {
        case .office:
            return nil
        case .meeting(let progress):
            return min(max(progress, 0), 1)
        case .liveMeeting(let startedAt, let duration):
            guard duration > 0 else { return 1 }
            return min(max(CGFloat(date.timeIntervalSince(startedAt) / duration), 0), 1)
        case .liveMeetingFromHuddle(let startedAt, let duration, _):
            guard duration > 0 else { return 1 }
            return min(max(CGFloat(date.timeIntervalSince(startedAt) / duration), 0), 1)
        case .liveHuddle:
            return nil
        }
    }

    private func bubbleCanAppear(at date: Date, meetingProgress: CGFloat?) -> Bool {
        if case let .liveHuddle(startedAt, duration, _, _) = mode {
            guard duration > 0 else { return false }
            let progress = CGFloat(date.timeIntervalSince(startedAt) / duration)
            return progress >= AnalysisMeetingPacing.huddleArrivalProgress
                && progress <= AnalysisMeetingPacing.huddleReturnStartProgress
        }
        guard let meetingProgress else { return true }
        return meetingProgress > 0.98
    }

    private func renderState(
        index: Int,
        time: Double,
        size: CGSize,
        meetingProgress: CGFloat?
    ) -> OfficeAgentState {
        if case let .liveHuddle(startedAt, duration, participants, returnsToStations) = mode {
            let progress = duration > 0
                ? CGFloat((time - startedAt.timeIntervalSinceReferenceDate) / duration)
                : 1
            return huddleState(
                index: index,
                progress: min(max(progress, 0), 1),
                participants: participants,
                returnsToStations: returnsToStations,
                size: size
            )
        }

        if case let .liveMeetingFromHuddle(_, _, participants) = mode,
           let meetingProgress {
            return meetingStateFromHuddle(
                index: index,
                progress: meetingProgress,
                participants: participants,
                size: size
            )
        }

        if let meetingProgress {
            return meetingState(index: index, progress: meetingProgress, size: size)
        } else {
            if isAutonomous && !isAnalyzing {
                return autonomousState(index: index, time: time, size: size)
            } else {
                return state(
                    at: OfficeLayout.station(index),
                    direction: OfficeLayout.stationDirection(index),
                    pose: isAnalyzing ? .sitting : .idle,
                    size: size
                )
            }
        }
    }

    private func huddleState(
        index: Int,
        progress: CGFloat,
        participants: [Int],
        returnsToStations: Bool,
        size: CGSize
    ) -> OfficeAgentState {
        guard participants.contains(index) else {
            return state(
                at: OfficeLayout.station(index),
                direction: OfficeLayout.stationDirection(index),
                pose: .sitting,
                size: size
            )
        }

        let route = OfficeLayout.huddleRoute(index, participants: participants)
        if !returnsToStations, progress >= AnalysisMeetingPacing.huddleArrivalProgress {
            return state(
                at: OfficeLayout.huddlePoint(index, participants: participants),
                direction: huddleFacingDirection(index: index, participants: participants, size: size),
                pose: index == focusedAgentIndex ? .talking : .idle,
                size: size
            )
        }
        switch progress {
        case ..<AnalysisMeetingPacing.huddleDepartureProgress:
            return state(at: OfficeLayout.station(index), direction: OfficeLayout.stationDirection(index), pose: .sitting, size: size)
        case ..<AnalysisMeetingPacing.huddleWalkStartProgress:
            return state(at: OfficeLayout.station(index), direction: OfficeLayout.exitDirection(index), pose: .idle, size: size)
        case ..<AnalysisMeetingPacing.huddleArrivalProgress:
            let travel = AnalysisMeetingPacing.huddleArrivalProgress - AnalysisMeetingPacing.huddleWalkStartProgress
            return moving(
                along: route,
                progress: (progress - AnalysisMeetingPacing.huddleWalkStartProgress) / travel,
                size: size
            )
        case ..<AnalysisMeetingPacing.huddleReturnStartProgress:
            return state(
                at: OfficeLayout.huddlePoint(index, participants: participants),
                direction: huddleFacingDirection(index: index, participants: participants, size: size),
                pose: index == focusedAgentIndex ? .talking : .idle,
                size: size
            )
        case ..<AnalysisMeetingPacing.huddleReturnEndProgress:
            let travel = AnalysisMeetingPacing.huddleReturnEndProgress - AnalysisMeetingPacing.huddleReturnStartProgress
            return moving(
                along: Array(route.reversed()),
                progress: (progress - AnalysisMeetingPacing.huddleReturnStartProgress) / travel,
                size: size
            )
        case ..<AnalysisMeetingPacing.huddleSitProgress:
            return state(at: OfficeLayout.station(index), direction: OfficeLayout.stationDirection(index), pose: .idle, size: size)
        default:
            return state(at: OfficeLayout.station(index), direction: OfficeLayout.stationDirection(index), pose: .sitting, size: size)
        }
    }

    private func meetingState(index: Int, progress: CGFloat, size: CGSize) -> OfficeAgentState {
        let value = min(max(progress, 0), 1)
        let departure = OfficeLayout.meetingDeparture(index)
        let walkStart = departure + 0.04
        let arrival = OfficeLayout.meetingArrival(index)

        if value < departure {
            return state(
                at: OfficeLayout.station(index),
                direction: OfficeLayout.stationDirection(index),
                pose: .sitting,
                size: size
            )
        }

        if value < walkStart {
            return state(
                at: OfficeLayout.station(index),
                direction: OfficeLayout.exitDirection(index),
                pose: .idle,
                size: size
            )
        }

        if value >= arrival {
            return state(
                at: OfficeLayout.meeting(index),
                direction: meetingFacingDirection(index: index, size: size),
                pose: .idle,
                size: size
            )
        }

        let local = min(max((value - walkStart) / (arrival - walkStart), 0), 1)
        let eased = local * local * (3 - 2 * local)
        return moving(along: OfficeLayout.meetingRoute(index), progress: eased, size: size)
    }

    private func meetingStateFromHuddle(
        index: Int,
        progress: CGFloat,
        participants: [Int],
        size: CGSize
    ) -> OfficeAgentState {
        let value = min(max(progress, 0), 1)
        let startsInHuddle = participants.contains(index)
        let origin = startsInHuddle
            ? OfficeLayout.huddlePoint(index, participants: participants)
            : OfficeLayout.station(index)
        let walkStart: CGFloat = startsInHuddle ? 0.02 : 0.06
        let arrival: CGFloat = 0.82

        if value < walkStart {
            return state(
                at: origin,
                direction: startsInHuddle
                    ? huddleFacingDirection(index: index, participants: participants, size: size)
                    : OfficeLayout.exitDirection(index),
                pose: .idle,
                size: size
            )
        }
        if value >= arrival {
            return state(
                at: OfficeLayout.meeting(index),
                direction: meetingFacingDirection(index: index, size: size),
                pose: .idle,
                size: size
            )
        }

        let local = min(max((value - walkStart) / (arrival - walkStart), 0), 1)
        let eased = local * local * (3 - 2 * local)
        return moving(
            along: OfficeLayout.meetingRouteFromHuddle(index, participants: participants),
            progress: eased,
            size: size
        )
    }

    private func autonomousState(index: Int, time: Double, size: CGSize) -> OfficeAgentState {
        let cycle = 18.0
        let local = (time + Double(index) * 3.15).truncatingRemainder(dividingBy: cycle)
        let seat = OfficeLayout.station(index)
        let outbound = OfficeLayout.roamRoute(index)
        let inbound = Array(outbound.reversed())
        let secondLeg = axisAlignedRoute([outbound.last ?? seat, OfficeLayout.roamB(index)])
        let secondLegReturn = Array(secondLeg.reversed())

        switch local {
        case 0..<3.2:
            return state(at: seat, direction: OfficeLayout.stationDirection(index), pose: .sitting, size: size)
        case 3.2..<4.0:
            return state(at: seat, direction: OfficeLayout.exitDirection(index), pose: .idle, size: size)
        case 4.0..<7.3:
            return moving(along: outbound, progress: CGFloat((local - 4.0) / 3.3), size: size)
        case 7.3..<9.2:
            return state(at: outbound.last ?? seat, direction: OfficeLayout.idleDirection(index), pose: .idle, size: size)
        case 9.2..<11.3:
            return moving(along: secondLeg, progress: CGFloat((local - 9.2) / 2.1), size: size)
        case 11.3..<12.4:
            return state(at: OfficeLayout.roamB(index), direction: OfficeLayout.idleDirection(index + 1), pose: .idle, size: size)
        case 12.4..<13.3:
            return moving(along: secondLegReturn, progress: CGFloat((local - 12.4) / 0.9), size: size)
        case 13.3..<16.7:
            return moving(along: inbound, progress: CGFloat((local - 13.3) / 3.4), size: size)
        default:
            return state(at: seat, direction: OfficeLayout.stationDirection(index), pose: .sitting, size: size)
        }
    }

    private func moving(along route: [UnitPoint], progress: CGFloat, size: CGSize) -> OfficeAgentState {
        guard route.count > 1 else {
            return state(at: route.first ?? .center, direction: .front, pose: .idle, size: size)
        }

        let points = axisAlignedRoute(route).map { $0.point(in: size) }
        let segmentLengths = zip(points, points.dropFirst()).map { start, end in
            hypot(end.x - start.x, end.y - start.y)
        }
        let totalLength = segmentLengths.reduce(0, +)
        guard totalLength > 0 else {
            return OfficeAgentState(point: points[0], direction: .front, pose: .idle)
        }

        let clamped = min(max(progress, 0), 1)
        let targetDistance = clamped * totalLength
        var consumed: CGFloat = 0

        for index in segmentLengths.indices {
            let length = segmentLengths[index]
            if targetDistance <= consumed + length || index == segmentLengths.indices.last {
                let local = length > 0 ? (targetDistance - consumed) / length : 0
                return moving(from: points[index], to: points[index + 1], progress: local)
            }
            consumed += length
        }

        return OfficeAgentState(point: points.last ?? .zero, direction: .front, pose: .idle)
    }

    private func moving(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> OfficeAgentState {
        let value = min(max(progress, 0), 1)
        let dx = end.x - start.x
        let dy = end.y - start.y

        if abs(dx) > 0.5, abs(dy) > 0.5 {
            // Defensive fallback: even a future malformed route is converted
            // into horizontal-then-vertical movement instead of a diagonal.
            let horizontalDistance = abs(dx)
            let totalDistance = horizontalDistance + abs(dy)
            let split = horizontalDistance / totalDistance
            if value <= split {
                let local = split > 0 ? value / split : 1
                let point = CGPoint(x: start.x + dx * local, y: start.y)
                return OfficeAgentState(point: point, direction: dx > 0 ? .right : .left, pose: .walking)
            }

            let local = (value - split) / (1 - split)
            let point = CGPoint(x: end.x, y: start.y + dy * local)
            return OfficeAgentState(point: point, direction: dy > 0 ? .front : .back, pose: .walking)
        }

        let point = abs(dx) > abs(dy)
            ? CGPoint(x: start.x + dx * value, y: start.y)
            : CGPoint(x: start.x, y: start.y + dy * value)
        return OfficeAgentState(point: point, direction: direction(from: start, to: end), pose: .walking)
    }

    private func axisAlignedRoute(_ route: [UnitPoint]) -> [UnitPoint] {
        guard let first = route.first else { return [] }
        var result = [first]

        for destination in route.dropFirst() {
            guard let origin = result.last else { continue }
            let movesHorizontally = abs(destination.x - origin.x) > 0.0001
            let movesVertically = abs(destination.y - origin.y) > 0.0001
            if movesHorizontally, movesVertically {
                result.append(UnitPoint(x: destination.x, y: origin.y))
            }
            result.append(destination)
        }

        return result
    }

    private func state(at point: UnitPoint, direction: PixelDirection, pose: PixelAgentPose, size: CGSize) -> OfficeAgentState {
        OfficeAgentState(point: point.point(in: size), direction: direction, pose: pose)
    }

    private func direction(from start: CGPoint, to end: CGPoint) -> PixelDirection {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if abs(dx) > abs(dy) { return dx > 0 ? .right : .left }
        return dy > 0 ? .front : .back
    }

    private func meetingFacingDirection(index: Int, size: CGSize) -> PixelDirection {
        guard let speaker = focusedAgentIndex,
              discussionAgentIndices.contains(speaker),
              discussionAgentIndices.contains(index) else {
            return OfficeLayout.meetingDirection(index)
        }

        let targetIndex = index == speaker
            ? discussionAgentIndices.first(where: { $0 != speaker })
            : speaker
        guard let targetIndex else { return OfficeLayout.meetingDirection(index) }
        return direction(
            from: OfficeLayout.meeting(index).point(in: size),
            to: OfficeLayout.meeting(targetIndex).point(in: size)
        )
    }

    private func huddleFacingDirection(index: Int, participants: [Int], size: CGSize) -> PixelDirection {
        let targetIndex: Int?
        if let speaker = focusedAgentIndex, participants.contains(speaker) {
            targetIndex = index == speaker ? participants.first(where: { $0 != speaker }) : speaker
        } else {
            targetIndex = participants.first(where: { $0 != index })
        }
        guard let targetIndex else { return OfficeLayout.idleDirection(index) }
        return direction(
            from: OfficeLayout.huddlePoint(index, participants: participants).point(in: size),
            to: OfficeLayout.huddlePoint(targetIndex, participants: participants).point(in: size)
        )
    }

    @MainActor
    private func replaceBubble(with request: OfficeBubbleEvent?) async {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeBubble = nil
            typedBubble = ""
            isBubbleTyping = false
        }
        guard let request else { return }

        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return }
        withTransaction(transaction) {
            activeBubble = request
            isBubbleTyping = true
        }
        onBubbleTypingUpdate?(
            OfficeBubbleTypingUpdate(
                targetText: request.text,
                visibleText: "",
                isTyping: true
            )
        )

        let interval = OfficeBubbleTypingPolicy.characterInterval(
            characterCount: request.text.count,
            budget: bubbleTypingBudget
        )
        for character in request.text {
            guard !Task.isCancelled else { return }
            typedBubble.append(character)
            onBubbleTypingUpdate?(
                OfficeBubbleTypingUpdate(
                    targetText: request.text,
                    visibleText: typedBubble,
                    isTyping: true
                )
            )
            try? await Task.sleep(for: .seconds(interval))
        }
        guard !Task.isCancelled, activeBubble == request else { return }
        withTransaction(transaction) {
            isBubbleTyping = false
        }
        onBubbleTypingUpdate?(
            OfficeBubbleTypingUpdate(
                targetText: request.text,
                visibleText: request.text,
                isTyping: false
            )
        )
    }
}

struct OfficeBubbleTypingUpdate: Equatable, Sendable {
    let targetText: String
    let visibleText: String
    let isTyping: Bool
}

enum OfficeBubbleTypingPolicy {
    static func characterInterval(characterCount: Int, budget: TimeInterval) -> TimeInterval {
        guard characterCount > 0 else { return 0 }
        let safeBudget = max(0.08, budget) * 0.92
        return min(0.026, safeBudget / Double(characterCount))
    }

    static func totalTypingDuration(characterCount: Int, budget: TimeInterval) -> TimeInterval {
        characterInterval(characterCount: characterCount, budget: budget) * Double(max(0, characterCount))
    }
}

private struct OfficeBubbleEvent: Hashable {
    let speakerIndex: Int
    let text: String
}

private struct OfficeAmbientRemark {
    let speakerIndex: Int
    let text: String
}

private struct OfficeAgentState {
    let point: CGPoint
    let direction: PixelDirection
    let pose: PixelAgentPose
}

private enum OfficeLayout {
    private static let stations: [UnitPoint] = [
        UnitPoint(x: 0.18, y: 0.330),
        UnitPoint(x: 0.48, y: 0.360),
        UnitPoint(x: 0.80, y: 0.310),
        UnitPoint(x: 0.248, y: 0.755),
        UnitPoint(x: 0.75, y: 0.725)
    ]

    // Each route first clears the chair toward an open aisle before turning.
    // Clearance includes the character's visible half-width, not just its anchor.
    // No segment crosses a desk, monitor, chair, cabinet, or wall display.
    private static let stationExitRoutes: [[UnitPoint]] = [
        [stations[0], UnitPoint(x: stations[0].x, y: 0.405), UnitPoint(x: 0.29, y: 0.405), UnitPoint(x: 0.29, y: 0.455)],
        [stations[1], UnitPoint(x: stations[1].x, y: 0.430), UnitPoint(x: 0.36, y: 0.430), UnitPoint(x: 0.36, y: 0.465)],
        [stations[2], UnitPoint(x: stations[2].x, y: 0.390), UnitPoint(x: 0.70, y: 0.390), UnitPoint(x: 0.70, y: 0.455)],
        [stations[3], UnitPoint(x: stations[3].x, y: 0.825), UnitPoint(x: 0.36, y: 0.825), UnitPoint(x: 0.36, y: 0.835)],
        [stations[4], UnitPoint(x: stations[4].x, y: 0.810), UnitPoint(x: 0.64, y: 0.810), UnitPoint(x: 0.64, y: 0.825)]
    ]

    private static let meetingPoints: [UnitPoint] = [
        UnitPoint(x: 0.50, y: 0.43),
        UnitPoint(x: 0.30, y: 0.57),
        UnitPoint(x: 0.70, y: 0.57),
        UnitPoint(x: 0.39, y: 0.73),
        UnitPoint(x: 0.62, y: 0.72)
    ]

    static func station(_ index: Int) -> UnitPoint { stations[index % 5] }
    static func meeting(_ index: Int) -> UnitPoint { meetingPoints[index % 5] }

    static func huddlePoint(_ index: Int, participants: [Int]) -> UnitPoint {
        let ordered = participants.filter { stations.indices.contains($0) }
        let slot = ordered.firstIndex(of: index) ?? 0
        let speaker = ordered.first ?? index
        let usesRightSide = stations[speaker % stations.count].x >= 0.5
        let pair = usesRightSide
            ? [UnitPoint(x: 0.44, y: 0.46), UnitPoint(x: 0.60, y: 0.46)]
            : [UnitPoint(x: 0.21, y: 0.53), UnitPoint(x: 0.34, y: 0.50)]
        let trio = usesRightSide
            ? [UnitPoint(x: 0.50, y: 0.42), UnitPoint(x: 0.37, y: 0.49), UnitPoint(x: 0.63, y: 0.49)]
            : [UnitPoint(x: 0.20, y: 0.51), UnitPoint(x: 0.34, y: 0.49), UnitPoint(x: 0.27, y: 0.67)]
        let points = ordered.count >= 3 ? trio : pair
        return points[min(slot, points.count - 1)]
    }

    static func huddleRoute(_ index: Int, participants: [Int]) -> [UnitPoint] {
        let target = huddlePoint(index, participants: participants)
        if index < 3 {
            let aisleY: CGFloat = 0.46
            return stationExitRoutes[index % 5] + [UnitPoint(x: target.x, y: aisleY), target]
        }

        // Bottom agents keep their station's inner corridor x-coordinate until
        // they are above the workstation footprint. Turning early here made
        // Gadi and Devil walk through the lower-right chair and desk.
        let corridorX = stationExitRoutes[index % 5].last?.x ?? target.x
        return stationExitRoutes[index % 5] + [UnitPoint(x: corridorX, y: target.y), target]
    }

    static func meetingRoute(_ index: Int) -> [UnitPoint] {
        // Individually authored Manhattan routes keep each entrance readable
        // and prevent agents from cutting through the evidence table.
        [
            stationExitRoutes[0] + [UnitPoint(x: 0.29, y: 0.430), meetingPoints[0]],
            stationExitRoutes[1] + [UnitPoint(x: 0.30, y: 0.465), meetingPoints[1]],
            stationExitRoutes[2] + [UnitPoint(x: 0.70, y: 0.470), meetingPoints[2]],
            stationExitRoutes[3] + [UnitPoint(x: 0.38, y: 0.835), UnitPoint(x: 0.38, y: 0.730), meetingPoints[3]],
            stationExitRoutes[4] + [UnitPoint(x: 0.63, y: 0.825), UnitPoint(x: 0.63, y: 0.720), meetingPoints[4]]
        ][index % 5]
    }

    static func meetingRouteFromHuddle(_ index: Int, participants: [Int]) -> [UnitPoint] {
        guard participants.contains(index) else { return meetingRoute(index) }
        let origin = huddlePoint(index, participants: participants)
        let target = meeting(index)
        return [origin, UnitPoint(x: target.x, y: origin.y), target]
    }

    static func meetingDeparture(_ index: Int) -> CGFloat {
        0.04
    }

    static func meetingArrival(_ index: Int) -> CGFloat {
        0.90
    }

    static func roamRoute(_ index: Int) -> [UnitPoint] {
        let destinations = [
            UnitPoint(x: 0.30, y: 0.515), UnitPoint(x: 0.43, y: 0.505),
            UnitPoint(x: 0.66, y: 0.515), UnitPoint(x: 0.42, y: 0.535),
            UnitPoint(x: 0.58, y: 0.535)
        ]
        return stationExitRoutes[index % 5] + [destinations[index % 5]]
    }

    static func roamB(_ index: Int) -> UnitPoint {
        [
            UnitPoint(x: 0.34, y: 0.550), UnitPoint(x: 0.46, y: 0.540),
            UnitPoint(x: 0.62, y: 0.550), UnitPoint(x: 0.40, y: 0.500),
            UnitPoint(x: 0.60, y: 0.500)
        ][index % 5]
    }

    static func stationDirection(_ index: Int) -> PixelDirection { [.back, .back, .back, .back, .back][index % 5] }
    static func exitDirection(_ index: Int) -> PixelDirection { [.front, .front, .front, .front, .front][index % 5] }
    static func meetingDirection(_ index: Int) -> PixelDirection { [.front, .right, .left, .back, .back][index % 5] }
    static func idleDirection(_ index: Int) -> PixelDirection { [.right, .front, .left, .right, .left][index % 5] }
}

private enum OfficePalette {
    static let floor = Color(red: 0.34, green: 0.235, blue: 0.135)
    static let grout = Color.black.opacity(0.14)
    static let wood = Color(red: 0.50, green: 0.30, blue: 0.13)
    static let woodDark = Color(red: 0.25, green: 0.135, blue: 0.055)
    static let woodLight = Color(red: 0.64, green: 0.40, blue: 0.18)
    static let metal = Color(red: 0.11, green: 0.12, blue: 0.13)
    static let metalLight = Color(red: 0.21, green: 0.23, blue: 0.25)
    static let screen = Color(red: 0.02, green: 0.055, blue: 0.075)
    static let frame = Color(red: 0.31, green: 0.215, blue: 0.13)
}

private struct OfficeFurnitureLayer: View {
    let showsMeetingTable: Bool

    var body: some View {
        Canvas { context, size in
            drawFloor(context: &context, size: size)
            drawWallChart(context: &context, size: size)
            drawClock(context: &context, size: size)
            drawWorkstations(context: &context, size: size)
            drawDecor(context: &context, size: size)
            if showsMeetingTable {
                drawMeetingTable(context: &context, size: size)
            }
        }
    }

    private func drawFloor(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OfficePalette.floor))
        let tile: CGFloat = 32
        var row = 0
        for y in stride(from: CGFloat(0), through: size.height, by: tile) {
            var column = 0
            for x in stride(from: CGFloat(0), through: size.width, by: tile) {
                if (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: x, y: y, width: tile, height: tile)), with: .color(.white.opacity(0.012)))
                }
                column += 1
            }
            row += 1
        }
        for x in stride(from: CGFloat(0), through: size.width, by: tile) {
            context.stroke(line(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: size.height)), with: .color(OfficePalette.grout), lineWidth: 2)
        }
        for y in stride(from: CGFloat(0), through: size.height, by: tile) {
            context.stroke(line(from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y)), with: .color(OfficePalette.grout), lineWidth: 2)
        }
    }

    private func drawWallChart(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.11, y: 13, width: size.width * 0.64, height: max(66, size.height * 0.15))
        context.fill(Path(rect.offsetBy(dx: 0, dy: 4).insetBy(dx: -5, dy: -5)), with: .color(.black.opacity(0.34)))
        context.fill(Path(rect.insetBy(dx: -4, dy: -4)), with: .color(OfficePalette.metal))
        context.fill(Path(rect), with: .color(OfficePalette.screen))
        for row in 1..<4 {
            let y = rect.minY + CGFloat(row) * rect.height / 4
            context.stroke(line(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y)), with: .color(.white.opacity(0.055)), lineWidth: 1)
        }
        for index in 0..<18 {
            let x = rect.minX + 10 + CGFloat(index) * (rect.width - 20) / 17
            let wave = sin(Double(index) * 0.74) * 10 - Double(index) * 0.22
            let y = rect.midY + CGFloat(wave)
            let rising = index % 5 != 0
            let color = rising ? ChartTheme.mint : ChartTheme.coral
            context.fill(Path(CGRect(x: x, y: y - (rising ? 8 : 2), width: 4, height: 11)), with: .color(color))
            context.fill(Path(CGRect(x: x + 1.5, y: y - 12, width: 1, height: 22)), with: .color(color))
        }
    }

    private func drawClock(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.87, y: size.height * 0.09)
        let rect = CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)
        context.fill(Path(ellipseIn: rect.offsetBy(dx: 2, dy: 3)), with: .color(.black.opacity(0.30)))
        context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.91, green: 0.86, blue: 0.72)))
        context.stroke(Path(ellipseIn: rect), with: .color(OfficePalette.woodDark), lineWidth: 3)
        context.stroke(line(from: center, to: CGPoint(x: center.x, y: center.y - 8)), with: .color(.black), lineWidth: 2)
        context.stroke(line(from: center, to: CGPoint(x: center.x + 7, y: center.y + 2)), with: .color(.black), lineWidth: 2)
    }

    private func drawWorkstations(context: inout GraphicsContext, size: CGSize) {
        workstation(context: &context, center: CGPoint(x: size.width * 0.18, y: size.height * 0.27), width: 66, style: .single)
        workstation(context: &context, center: CGPoint(x: size.width * 0.48, y: size.height * 0.30), width: 82, style: .dual)
        workstation(context: &context, center: CGPoint(x: size.width * 0.80, y: size.height * 0.25), width: 60, style: .laptop)
        workstation(context: &context, center: CGPoint(x: size.width * 0.24, y: size.height * 0.70), width: 74, style: .drawer)
        workstation(context: &context, center: CGPoint(x: size.width * 0.75, y: size.height * 0.67), width: 68, style: .lamp)
    }

    private func workstation(context: inout GraphicsContext, center: CGPoint, width: CGFloat, style: WorkstationStyle) {
        drawDesk(context: &context, center: center, width: width, style: style)
        drawMonitor(context: &context, center: center, style: style)
        drawChair(context: &context, center: CGPoint(x: center.x, y: center.y + 31), style: style)
        drawDeskProps(context: &context, center: center, width: width, style: style)
    }

    private func drawDesk(context: inout GraphicsContext, center: CGPoint, width: CGFloat, style: WorkstationStyle) {
        let slab = CGRect(x: center.x - width / 2, y: center.y - 7, width: width, height: 14)
        context.fill(Path(slab.offsetBy(dx: 2, dy: 4)), with: .color(.black.opacity(0.28)))
        context.fill(Path(slab), with: .color(OfficePalette.wood))
        context.fill(Path(CGRect(x: slab.minX + 2, y: slab.minY + 2, width: slab.width - 4, height: 2)), with: .color(OfficePalette.woodLight))
        context.stroke(Path(slab), with: .color(OfficePalette.woodDark), lineWidth: 2)

        if style == .drawer {
            let drawer = CGRect(x: slab.minX + 4, y: slab.maxY, width: 18, height: 24)
            context.fill(Path(drawer), with: .color(OfficePalette.woodDark))
            context.fill(Path(CGRect(x: drawer.minX + 3, y: drawer.minY + 4, width: 12, height: 7)), with: .color(OfficePalette.wood))
            context.fill(Path(CGRect(x: drawer.minX + 3, y: drawer.minY + 14, width: 12, height: 7)), with: .color(OfficePalette.wood))
            context.fill(Path(CGRect(x: drawer.midX - 2, y: drawer.minY + 7, width: 4, height: 2)), with: .color(ChartTheme.amber.opacity(0.72)))
            context.fill(Path(CGRect(x: drawer.midX - 2, y: drawer.minY + 17, width: 4, height: 2)), with: .color(ChartTheme.amber.opacity(0.72)))
        } else {
            context.fill(Path(CGRect(x: slab.minX + 5, y: slab.maxY, width: 5, height: 17)), with: .color(OfficePalette.woodDark))
        }
        context.fill(Path(CGRect(x: slab.maxX - 10, y: slab.maxY, width: 5, height: style == .laptop ? 12 : 17)), with: .color(OfficePalette.woodDark))
    }

    private func drawMonitor(context: inout GraphicsContext, center: CGPoint, style: WorkstationStyle) {
        switch style {
        case .single, .drawer, .lamp:
            let width: CGFloat = style == .drawer ? 30 : 28
            monitor(context: &context, rect: CGRect(x: center.x - width / 2, y: center.y - 26, width: width, height: 18), accent: style == .lamp ? ChartTheme.amber : ChartTheme.mint)
        case .dual:
            monitor(context: &context, rect: CGRect(x: center.x - 31, y: center.y - 27, width: 27, height: 18), accent: ChartTheme.mint)
            monitor(context: &context, rect: CGRect(x: center.x + 4, y: center.y - 27, width: 27, height: 18), accent: ChartTheme.blue)
        case .laptop:
            let screen = CGRect(x: center.x - 15, y: center.y - 24, width: 30, height: 17)
            context.fill(Path(screen), with: .color(OfficePalette.metalLight))
            context.fill(Path(screen.insetBy(dx: 3, dy: 3)), with: .color(OfficePalette.screen))
            context.fill(Path(CGRect(x: screen.minX - 4, y: screen.maxY, width: screen.width + 8, height: 4)), with: .color(OfficePalette.metal))
            context.fill(Path(CGRect(x: screen.midX - 7, y: screen.midY, width: 14, height: 2)), with: .color(ChartTheme.mint))
        }
    }

    private func monitor(context: inout GraphicsContext, rect: CGRect, accent: Color) {
        context.fill(Path(rect.offsetBy(dx: 2, dy: 3)), with: .color(.black.opacity(0.30)))
        context.fill(Path(rect), with: .color(OfficePalette.metalLight))
        context.fill(Path(rect.insetBy(dx: 3, dy: 3)), with: .color(OfficePalette.screen))
        context.fill(Path(CGRect(x: rect.minX + 6, y: rect.midY - 1, width: rect.width - 12, height: 2)), with: .color(accent))
        context.fill(Path(CGRect(x: rect.midX - 2, y: rect.maxY, width: 4, height: 5)), with: .color(OfficePalette.metal))
    }

    private func drawChair(context: inout GraphicsContext, center: CGPoint, style: WorkstationStyle) {
        let upholstery = style == .dual
            ? Color(red: 0.13, green: 0.20, blue: 0.23)
            : OfficePalette.metalLight
        // A low armless swivel seat keeps the dedicated sitting frame readable
        // without a tall backrest intersecting the character's torso.
        let seat = CGRect(x: center.x - 12, y: center.y + 3, width: 24, height: 8)
        context.fill(Path(seat.offsetBy(dx: 2, dy: 2)), with: .color(.black.opacity(0.28)))
        context.fill(Path(seat), with: .color(upholstery))
        context.fill(Path(CGRect(x: seat.minX + 3, y: seat.minY + 2, width: seat.width - 6, height: 2)), with: .color(.white.opacity(0.10)))
        context.fill(Path(CGRect(x: center.x - 2, y: center.y + 11, width: 4, height: 12)), with: .color(OfficePalette.metal))
        context.fill(Path(CGRect(x: center.x - 10, y: center.y + 21, width: 20, height: 3)), with: .color(OfficePalette.metal))
        context.fill(Path(CGRect(x: center.x - 12, y: center.y + 22, width: 4, height: 4)), with: .color(.black.opacity(0.65)))
        context.fill(Path(CGRect(x: center.x + 8, y: center.y + 22, width: 4, height: 4)), with: .color(.black.opacity(0.65)))
    }

    private func drawDeskProps(context: inout GraphicsContext, center: CGPoint, width: CGFloat, style: WorkstationStyle) {
        switch style {
        case .single:
            context.fill(Path(CGRect(x: center.x - width / 2 + 7, y: center.y - 4, width: 12, height: 7)), with: .color(Color(red: 0.90, green: 0.84, blue: 0.68)))
            context.stroke(line(from: CGPoint(x: center.x - width / 2 + 9, y: center.y - 1), to: CGPoint(x: center.x - width / 2 + 16, y: center.y - 1)), with: .color(ChartTheme.coral), lineWidth: 1)
        case .dual:
            context.fill(Path(CGRect(x: center.x - 12, y: center.y - 4, width: 24, height: 5)), with: .color(OfficePalette.metal))
        case .laptop:
            context.fill(Path(ellipseIn: CGRect(x: center.x + width / 2 - 13, y: center.y - 5, width: 7, height: 7)), with: .color(ChartTheme.amber))
        case .drawer:
            context.fill(Path(CGRect(x: center.x + width / 2 - 20, y: center.y - 4, width: 13, height: 7)), with: .color(Color(red: 0.90, green: 0.84, blue: 0.68)))
            context.fill(Path(CGRect(x: center.x + width / 2 - 18, y: center.y - 2, width: 9, height: 1)), with: .color(ChartTheme.coral))
        case .lamp:
            context.fill(Path(CGRect(x: center.x - width / 2 + 9, y: center.y - 19, width: 3, height: 15)), with: .color(OfficePalette.metalLight))
            context.fill(Path(CGRect(x: center.x - width / 2 + 5, y: center.y - 22, width: 12, height: 5)), with: .color(ChartTheme.amber))
        }
    }

    private func drawMeetingTable(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.585)
        let shadow = CGRect(x: center.x - 44, y: center.y - 21, width: 88, height: 50)
        let table = CGRect(x: center.x - 42, y: center.y - 25, width: 84, height: 48)
        context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.30)))
        context.fill(Path(ellipseIn: table), with: .color(OfficePalette.woodDark))
        context.fill(Path(ellipseIn: table.insetBy(dx: 3, dy: 3)), with: .color(OfficePalette.wood))
        context.stroke(Path(ellipseIn: table.insetBy(dx: 2, dy: 2)), with: .color(OfficePalette.woodLight), lineWidth: 2)
        context.fill(Path(CGRect(x: center.x - 8, y: center.y + 18, width: 16, height: 17)), with: .color(OfficePalette.woodDark))
        context.fill(Path(CGRect(x: center.x - 15, y: center.y + 32, width: 30, height: 6)), with: .color(OfficePalette.woodDark))
        context.fill(Path(CGRect(x: center.x - 19, y: center.y - 6, width: 14, height: 9)), with: .color(Color(red: 0.91, green: 0.84, blue: 0.68)))
        context.fill(Path(CGRect(x: center.x + 6, y: center.y - 3, width: 15, height: 8)), with: .color(Color(red: 0.08, green: 0.17, blue: 0.20)))
        context.fill(Path(CGRect(x: center.x + 8, y: center.y - 1, width: 11, height: 2)), with: .color(ChartTheme.mint))
    }

    private func drawDecor(context: inout GraphicsContext, size: CGSize) {
        let cabinet = CGRect(x: size.width * 0.86, y: size.height * 0.81, width: 34, height: 62)
        context.fill(Path(cabinet.offsetBy(dx: 3, dy: 3)), with: .color(.black.opacity(0.24)))
        context.fill(Path(cabinet), with: .color(OfficePalette.woodDark))
        context.fill(Path(CGRect(x: cabinet.minX + 3, y: cabinet.minY + 3, width: cabinet.width - 6, height: 3)), with: .color(OfficePalette.woodLight))
        for row in 0..<3 {
            let y = cabinet.minY + 12 + CGFloat(row) * 15
            context.fill(Path(CGRect(x: cabinet.minX + 6, y: y, width: 7, height: 8)), with: .color(row == 1 ? ChartTheme.amber : ChartTheme.mint))
            context.fill(Path(CGRect(x: cabinet.minX + 16, y: y + 2, width: 11, height: 6)), with: .color(ChartTheme.blue.opacity(0.75)))
        }

        let pot = CGRect(x: size.width * 0.07, y: size.height * 0.84, width: 17, height: 15)
        context.fill(Path(pot), with: .color(Color(red: 0.51, green: 0.23, blue: 0.07)))
        context.fill(Path(CGRect(x: pot.minX - 2, y: pot.minY, width: pot.width + 4, height: 3)), with: .color(Color(red: 0.66, green: 0.31, blue: 0.09)))
        for offset in [-8, 0, 8] as [CGFloat] {
            context.fill(Path(CGRect(x: pot.midX + offset - 5, y: pot.minY - 15 - abs(offset) * 0.18, width: 11, height: 12)), with: .color(Color(red: 0.10, green: 0.43 + Double(abs(offset)) * 0.004, blue: 0.16)))
        }

        let server = CGRect(x: size.width * 0.91, y: size.height * 0.21, width: 20, height: 44)
        context.fill(Path(server), with: .color(OfficePalette.metal))
        for row in 0..<4 {
            let y = server.minY + 6 + CGFloat(row) * 9
            context.fill(Path(CGRect(x: server.minX + 4, y: y, width: 7, height: 2)), with: .color(ChartTheme.mint.opacity(0.76)))
            context.fill(Path(CGRect(x: server.maxX - 6, y: y, width: 2, height: 2)), with: .color(row == 2 ? ChartTheme.coral : ChartTheme.amber))
        }
    }

    private func line(from: CGPoint, to: CGPoint) -> Path {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
    }

}

private struct MeetingEvidenceLayer: View {
    let progress: CGFloat
    let activeAgentIDs: Set<String>

    var body: some View {
        Canvas { context, size in
            drawEvidenceCards(context: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawEvidenceCards(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.585)
        let offsets = [
            CGPoint(x: -28, y: -8), CGPoint(x: -15, y: 8), CGPoint(x: 0, y: -10),
            CGPoint(x: 15, y: 8), CGPoint(x: 28, y: -6)
        ]

        for index in PixelAgent.team.indices {
            guard activeAgentIDs.contains(PixelAgent.team[index].id) else { continue }
            let arrival = OfficeLayout.meetingArrival(index)
            let reveal = min(max((progress - arrival) / 0.035, 0), 1)
            guard reveal > 0 else { continue }

            let origin = CGPoint(x: center.x + offsets[index].x, y: center.y + offsets[index].y)
            let card = CGRect(x: origin.x - 5, y: origin.y - 4, width: 10, height: 8)
            context.fill(Path(card.offsetBy(dx: 1, dy: 2)), with: .color(.black.opacity(0.24 * Double(reveal))))
            context.fill(Path(card), with: .color(Color(red: 0.90, green: 0.84, blue: 0.68).opacity(Double(reveal))))
            context.fill(
                Path(CGRect(x: card.minX + 2, y: card.minY + 2, width: 6, height: 2)),
                with: .color(PixelAgent.team[index].accent.opacity(Double(reveal)))
            )
            context.fill(
                Path(CGRect(x: card.minX + 2, y: card.maxY - 2, width: 4, height: 1)),
                with: .color(OfficePalette.metal.opacity(Double(reveal)))
            )
        }
    }

}

private enum WorkstationStyle {
    case single
    case dual
    case laptop
    case drawer
    case lamp
}

enum OfficeBubbleLayout {
    static let horizontalPadding: CGFloat = 20
    static let minimumWidth: CGFloat = 58

    static func width(text: String, showsCursor: Bool, maximum: CGFloat) -> CGFloat {
        let renderedText = showsCursor ? text + " ▌" : text
        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let bounds = (renderedText as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 24),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let singleLineWidth = ceil(bounds.width) + horizontalPadding
        guard singleLineWidth > maximum else {
            return min(maximum, max(minimumWidth, singleLineWidth))
        }

        let balancedWidth = ceil(sqrt(max(1, bounds.width) * 40)) + horizontalPadding
        return min(maximum, max(136, balancedWidth))
    }

    static func height(text: String, showsCursor: Bool, width: CGFloat) -> CGFloat {
        let renderedText = showsCursor ? text + " ▌" : text
        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let bounds = (renderedText as NSString).boundingRect(
            with: CGSize(width: max(1, width - horizontalPadding), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(44, ceil(bounds.height) + 20)
    }
}

private struct HeadAnchoredBubble: View {
    let text: String
    let showsCursor: Bool
    let speakerHead: CGPoint
    let availableSize: CGSize

    private let tailHeight: CGFloat = 10

    var body: some View {
        let maximumWidth = min(220, max(OfficeBubbleLayout.minimumWidth, availableSize.width - 24))
        let bubbleWidth = OfficeBubbleLayout.width(
            text: text,
            showsCursor: showsCursor,
            maximum: maximumWidth
        )
        let bubbleHeight = OfficeBubbleLayout.height(
            text: text,
            showsCursor: showsCursor,
            width: bubbleWidth
        )
        let centerX = min(max(speakerHead.x, bubbleWidth / 2 + 10), availableSize.width - bubbleWidth / 2 - 10)
        let left = centerX - bubbleWidth / 2
        let tailX = min(max(speakerHead.x - left - 7, 15), bubbleWidth - 29)
        let centerY = max(bubbleHeight / 2 + 8, speakerHead.y - bubbleHeight / 2 - tailHeight + 6)

        Text(renderedText)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: bubbleWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .bottomLeading) {
                BubbleTail().fill(.white).frame(width: 14, height: tailHeight).offset(x: tailX, y: tailHeight - 1)
            }
            .position(x: centerX, y: centerY)
            .shadow(color: .black.opacity(0.26), radius: 6, y: 3)
    }

    private var renderedText: String {
        showsCursor ? text + " ▌" : text
    }
}

private struct MinimalAgentPanel: View {
    let agent: PixelAgent
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            PixelAgentView(agent: agent, direction: .front, pose: .idle, phase: 0, scale: 0.88)
                .frame(width: 54, height: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(agent.localizedName)
                    .font(.headline.bold())
                Text(agent.localizedRole)
                    .font(.caption.bold())
                    .foregroundStyle(agent.accent)
                Text(agent.localizedDescription)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark").font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("에이전트 설명 닫기")
        }
        .padding(12)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(red: 0.08, green: 0.085, blue: 0.08).opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(agent.accent.opacity(0.32)) }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private extension UnitPoint {
    func point(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}
