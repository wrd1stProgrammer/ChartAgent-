import SwiftUI

enum PixelDirection: CaseIterable, Equatable {
    case front
    case back
    case left
    case right
}

enum PixelAgentPose: Equatable {
    case idle
    case walking
    case sitting
    case talking
    case reading
    case typing
}

enum AgentLook {
    case visorAnalyst
    case bobPattern
    case headphonesQuant
    case fieldRisk
    case hornedDissent
}

struct PixelAgent: Identifiable {
    let id: String
    let name: String
    let role: String
    let specialty: String
    let description: String
    let icon: String
    let accent: Color
    let outfit: Color
    let secondaryOutfit: Color
    let skin: Color
    let hair: Color
    let look: AgentLook
    let spriteAsset: String
    let officePosition: UnitPoint
    let meetingPosition: UnitPoint
    let officeDirection: PixelDirection
    let meetingDirection: PixelDirection
    let message: String
    let thesis: String
    let stance: String
    let confidence: Int
    let evidence: [String]

    var localizedName: String { AppLanguage.localized(name) }
    var localizedRole: String { AppLanguage.localized(role) }
    var localizedSpecialty: String { AppLanguage.localized(specialty) }
    var localizedDescription: String { AppLanguage.localized(description) }
    var localizedMessage: String { AppLanguage.localized(message) }
    var localizedThesis: String { AppLanguage.localized(thesis) }
    var localizedStance: String { AppLanguage.localized(stance) }
    var localizedEvidence: [String] { evidence.map(AppLanguage.localized) }

    static var team: [PixelAgent] { AgentProfileStore.shared.agents }

    static let defaultTeam: [PixelAgent] = [
        PixelAgent(
            id: "trend", name: "트렌디", role: "스윙 구조", specialty: "Swing Structure Analyst",
            description: "캡처 안의 고점·저점 배열을 HH·HL·LH·LL 구조로 분류하고, 추세 지속과 전환을 가르는 다음 가격 조건을 제시합니다.",
            icon: "chart.line.uptrend.xyaxis", accent: ChartTheme.mint,
            outfit: Color(red: 0.09, green: 0.33, blue: 0.68), secondaryOutfit: Color(red: 0.05, green: 0.12, blue: 0.23),
            skin: Color(red: 0.88, green: 0.66, blue: 0.48), hair: Color(red: 0.12, green: 0.08, blue: 0.06),
            look: .visorAnalyst, spriteAsset: "AgentTrendyAtlas", officePosition: UnitPoint(x: 0.74, y: 0.71), meetingPosition: UnitPoint(x: 0.50, y: 0.54),
            officeDirection: .back, meetingDirection: .front,
            message: "최근 스윙 고점과 저점의 순서를 먼저 맞춰볼게요.",
            thesis: "최근 스윙 고점 회복 전까지는 추세 전환보다 기존 구조 지속을 우선", stance: "구조 확인", confidence: 72,
            evidence: ["캡처 안의 고점·저점 순서 분류", "직전 스윙 회복 여부로 전환 확인", "화면 밖 이전 구조는 판단 대상에서 제외"]
        ),
        PixelAgent(
            id: "pattern", name: "패티", role: "캔들·경계", specialty: "Candle & Boundary Analyst",
            description: "캔들 몸통·꼬리와 반복되는 상단·하단 경계를 비교해 압축, 돌파, 재시험 패턴이 실제로 성립하는지 판정합니다.",
            icon: "waveform.path.ecg", accent: ChartTheme.violet,
            outfit: Color(red: 0.42, green: 0.21, blue: 0.68), secondaryOutfit: Color(red: 0.17, green: 0.08, blue: 0.27),
            skin: Color(red: 0.94, green: 0.72, blue: 0.55), hair: Color(red: 0.09, green: 0.07, blue: 0.08),
            look: .bobPattern, spriteAsset: "AgentPattyAtlas", officePosition: UnitPoint(x: 0.23, y: 0.72), meetingPosition: UnitPoint(x: 0.24, y: 0.67),
            officeDirection: .back, meetingDirection: .right,
            message: "이름 붙이기 전에 경계가 반복되는지부터 볼게요.",
            thesis: "상·하단 경계 이탈과 재시험 전에는 패턴 완성으로 보지 않음", stance: "경계 대기", confidence: 64,
            evidence: ["몸통과 꼬리가 멈춘 가격대 비교", "패턴 이름보다 경계 이탈 확인을 우선", "후속 캔들 없이 목표가를 만들지 않음"]
        ),
        PixelAgent(
            id: "momentum", name: "모모", role: "가격행동 강도", specialty: "Price Action Momentum",
            description: "연속 캔들의 몸통 크기, 꼬리, 진행 속도와 화면에 보이는 거래량만 비교해 매수·매도 힘이 가속되는지 약해지는지 판정합니다.",
            icon: "bolt.fill", accent: ChartTheme.blue,
            outfit: Color(red: 0.11, green: 0.47, blue: 0.58), secondaryOutfit: Color(red: 0.04, green: 0.18, blue: 0.22),
            skin: Color(red: 0.70, green: 0.49, blue: 0.34), hair: Color(red: 0.05, green: 0.05, blue: 0.05),
            look: .headphonesQuant, spriteAsset: "AgentMomoAtlas", officePosition: UnitPoint(x: 0.25, y: 0.40), meetingPosition: UnitPoint(x: 0.76, y: 0.67),
            officeDirection: .right, meetingDirection: .left,
            message: "몸통 확장과 꼬리 반응으로 힘의 변화를 비교할게요.",
            thesis: "진행 방향의 몸통 확장이 이어지지 않으면 추격보다 확인을 우선", stance: "강도 점검", confidence: 58,
            evidence: ["연속 캔들의 몸통 크기 변화 비교", "보이는 거래량만 보조 근거로 사용", "표시되지 않은 RSI·MACD 값은 만들지 않음"]
        ),
        PixelAgent(
            id: "risk", name: "가디", role: "레벨·무효화", specialty: "Level & Invalidation Analyst",
            description: "화면에서 반복 반응한 지지·저항과 최근 스윙을 기준으로 확인 구간과 무효화 구간을 분리합니다. 숫자가 흐리면 상대 위치로만 말합니다.",
            icon: "shield.fill", accent: ChartTheme.coral,
            outfit: Color(red: 0.25, green: 0.45, blue: 0.18), secondaryOutfit: Color(red: 0.10, green: 0.20, blue: 0.08),
            skin: Color(red: 0.82, green: 0.60, blue: 0.42), hair: Color(red: 0.30, green: 0.18, blue: 0.08),
            look: .fieldRisk, spriteAsset: "AgentGadiAtlas", officePosition: UnitPoint(x: 0.76, y: 0.40), meetingPosition: UnitPoint(x: 0.32, y: 0.86),
            officeDirection: .left, meetingDirection: .back,
            message: "판단이 틀렸다고 인정할 가격부터 정할게요.",
            thesis: "최근 반응 레벨을 지키는 동안만 현재 시나리오를 유지", stance: "조건부", confidence: 66,
            evidence: ["최근 스윙과 반복 반응 구간을 무효화 후보로 사용", "숫자가 흐리면 상대 위치로만 표현", "계좌 위험 비율은 차트 이미지에서 추정하지 않음"]
        ),
        PixelAgent(
            id: "devil", name: "데빌", role: "실패·페이크아웃", specialty: "False-break Analyst",
            description: "돌파 실패, 유동성 스윕, 재진입 같은 실패 패턴을 찾아 기본 시나리오가 뒤집히는 반대 조건을 한 가지로 압축합니다.",
            icon: "bubble.left.and.exclamationmark.bubble.right.fill", accent: ChartTheme.amber,
            outfit: Color(red: 0.10, green: 0.11, blue: 0.14), secondaryOutfit: Color(red: 0.42, green: 0.10, blue: 0.08),
            skin: Color(red: 0.91, green: 0.70, blue: 0.51), hair: Color(red: 0.12, green: 0.06, blue: 0.04),
            look: .hornedDissent, spriteAsset: "AgentDevilAtlas", officePosition: UnitPoint(x: 0.50, y: 0.86), meetingPosition: UnitPoint(x: 0.68, y: 0.86),
            officeDirection: .front, meetingDirection: .back,
            message: "이 돌파가 실패했을 때 무엇이 먼저 보일지 찾을게요.",
            thesis: "경계 이탈 뒤 즉시 재진입하면 돌파 추종 시나리오를 폐기", stance: "실패 검증", confidence: 70,
            evidence: ["돌파 뒤 경계 안 재진입 여부 확인", "긴 꼬리만으로 방향을 확정하지 않음", "반대 조건이 나오면 기본 판단을 즉시 낮춤"]
        )
    ]

    func applying(_ profile: AgentProfile) -> PixelAgent {
        let appearance = AgentAppearance.appearance(id: profile.appearanceID)
        return PixelAgent(
            id: id,
            name: profile.displayName,
            role: profile.concept.localizedTitle,
            specialty: profile.concept.localizedSummary,
            description: description,
            icon: icon,
            accent: appearance?.accent ?? accent,
            outfit: outfit,
            secondaryOutfit: secondaryOutfit,
            skin: skin,
            hair: hair,
            look: look,
            spriteAsset: appearance?.assetName ?? spriteAsset,
            officePosition: officePosition,
            meetingPosition: meetingPosition,
            officeDirection: officeDirection,
            meetingDirection: meetingDirection,
            message: message,
            thesis: thesis,
            stance: stance,
            confidence: confidence,
            evidence: evidence
        )
    }
}

enum AnalysisStage: Int, CaseIterable {
    case scanning
    case evidence
    case trend
    case pattern
    case momentum
    case risk
    case gathering
    case debateTrend
    case debateMomentum
    case dissent
    case synthesis
    case complete

    var title: String {
        let key: String = switch self {
        case .scanning: "차트 픽셀 스캔"
        case .evidence: "시장 증거 수집"
        case .trend: "추세 구조 리서치"
        case .pattern: "패턴 후보 검증"
        case .momentum: "강도 단서 점검"
        case .risk: "무효화 후보 점검"
        case .gathering: "에이전트 회의실 이동"
        case .debateTrend: "1차 교차 검증"
        case .debateMomentum: "2차 반론 회의"
        case .dissent: "반대 시나리오 검증"
        case .synthesis: "최종 판단 리포트 작성"
        case .complete: "분석 리포트 완성"
        }
        return AppLanguage.localized(key)
    }

    var detail: String {
        let key: String = switch self {
        case .scanning: "캔들·가격 축·주요 레벨을 구조화합니다"
        case .evidence: "이미지에서 직접 확인 가능한 캔들·축·라벨을 분리합니다"
        case .trend: "트렌디가 화면 안의 고점·저점 관계를 비교합니다"
        case .pattern: "패티가 패턴 후보와 무효화 조건을 분리합니다"
        case .momentum: "모모가 이미지에 표시된 거래량과 캔들 강도를 확인합니다"
        case .risk: "가디가 계산 가능한 항목과 추가 입력이 필요한 항목을 나눕니다"
        case .gathering: "에이전트가 순서대로 근거 카드를 들고 회의에 합류합니다"
        case .debateTrend: "추세 근거를 패턴 관점과 교차 검증합니다"
        case .debateMomentum: "이미지에 없는 강도 수치를 근거에서 제거합니다"
        case .dissent: "데빌이 다수 의견의 반대 시나리오를 제시합니다"
        case .synthesis: "현재 판단과 확인·무효화 조건을 한 장으로 정리합니다"
        case .complete: "에이전트별 판단과 근거 정리가 끝났습니다"
        }
        return AppLanguage.localized(key)
    }

    var focusedAgentIndex: Int? {
        switch self {
        case .trend, .debateTrend: 0
        case .pattern: 1
        case .momentum, .debateMomentum: 2
        case .risk: 3
        case .dissent: 4
        case .scanning, .evidence, .gathering, .synthesis, .complete: nil
        }
    }

    var isMeeting: Bool { rawValue >= AnalysisStage.gathering.rawValue }
}
