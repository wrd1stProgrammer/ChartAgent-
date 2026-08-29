import SwiftUI

struct PixelAgentView: View {
    let agent: PixelAgent
    var direction: PixelDirection = .front
    var pose: PixelAgentPose = .idle
    var phase: Double = 0
    var scale: CGFloat = 1
    var scaleAnchor: UnitPoint = .bottom
    var showsName = false
    var isSelected = false

    @State private var previousSprite: SpriteTransitionKey?
    @State private var spriteTransitionProgress: CGFloat = 1

    private var visiblePose: PixelAgentPose {
        switch pose {
        case .walking, .sitting: pose
        case .idle, .talking, .reading, .typing: .idle
        }
    }

    private var spriteColumn: Int {
        switch visiblePose {
        case .walking:
            // A neutral contact frame between the two strides keeps the side
            // profile readable instead of snapping directly foot-to-foot.
            [0, 1, 0, 2][Int(floor(phase * 7.2)).positiveRemainder(dividingBy: 4)]
        case .sitting:
            3
        default:
            0
        }
    }

    private var directionScale: CGFloat {
        guard agent.spriteAsset == "AgentDevilAtlas", visiblePose != .sitting else { return 1 }
        switch direction {
        case .front, .back:
            // Devil's horned front/back artwork has a taller source silhouette
            // than its side profile. Normalize the visible body around its feet.
            return 0.88
        case .left, .right:
            return 1
        }
    }

    private var transitionKey: SpriteTransitionKey {
        SpriteTransitionKey(direction: direction, pose: visiblePose)
    }

    var body: some View {
        VStack(spacing: -7) {
            ZStack {
                if let previousSprite, spriteTransitionProgress < 1 {
                    PixelAtlasFrame(
                        assetName: agent.spriteAsset,
                        row: previousSprite.direction.spriteRow,
                        column: previousSprite.pose == .sitting ? 3 : 0
                    )
                    .opacity(1 - spriteTransitionProgress)
                }

                PixelAtlasFrame(
                    assetName: agent.spriteAsset,
                    row: direction.spriteRow,
                    column: spriteColumn
                )
                .opacity(spriteTransitionProgress)
            }
            .scaleEffect(directionScale, anchor: .bottom)
            .frame(width: 64, height: 64)

            if showsName {
                Text(agent.localizedName)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .scaleEffect(scale, anchor: scaleAnchor)
        .onChange(of: transitionKey) { oldValue, newValue in
            guard oldValue.pose == .sitting || newValue.pose == .sitting else {
                previousSprite = nil
                spriteTransitionProgress = 1
                return
            }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                previousSprite = oldValue
                spriteTransitionProgress = 0
            }
            withAnimation(.easeOut(duration: 0.18)) {
                spriteTransitionProgress = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.localizedName), \(agent.localizedRole) \(AppLanguage.localized("에이전트"))")
        .accessibilityValue(
            AppLanguage.localized(
                visiblePose == .sitting ? "착석" : (visiblePose == .walking ? "이동 중" : "대기 중")
            )
        )
        .accessibilityHint("선택하면 에이전트 역할 설명을 엽니다")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SpriteTransitionKey: Equatable {
    let direction: PixelDirection
    let pose: PixelAgentPose
}

private extension Int {
    func positiveRemainder(dividingBy divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

private struct PixelAtlasFrame: View {
    let assetName: String
    let row: Int
    let column: Int

    private let cell: CGFloat = 64

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.none)
            .frame(width: cell * 4, height: cell * 4)
            .offset(
                x: (1.5 - CGFloat(column)) * cell,
                y: (1.5 - CGFloat(row)) * cell
            )
            .frame(width: cell, height: cell)
            .clipped()
            .accessibilityHidden(true)
    }
}

private extension PixelDirection {
    var spriteRow: Int {
        switch self {
        case .front: 0
        case .back: 1
        case .left: 2
        case .right: 3
        }
    }
}
