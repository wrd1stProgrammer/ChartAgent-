import Foundation
import SwiftUI

enum InvestmentConcept: String, Codable, CaseIterable, Identifiable {
    case trendFollowing = "trend_following"
    case swingStructure = "swing_structure"
    case breakoutRetest = "breakout_retest"
    case supportResistance = "support_resistance"
    case candlestick = "candlestick"
    case momentum = "momentum"
    case meanReversion = "mean_reversion"
    case volatilityBreakout = "volatility_breakout"
    case volumePriceAction = "volume_price_action"
    case movingAverage = "moving_average"
    case divergence = "divergence"
    case marketStructure = "market_structure"
    case liquiditySweep = "liquidity_sweep"
    case falseBreakout = "false_breakout"
    case riskInvalidation = "risk_invalidation"
    case riskReward = "risk_reward"
    case reversal = "reversal"
    case rangeTrading = "range_trading"
    case pullback = "pullback"
    case contrarian = "contrarian"

    var id: String { rawValue }

    var localizedTitle: String {
        AppLanguage.localized(localizationTitleKey)
    }

    var localizedSummary: String {
        if AppLanguage.current.responseLanguage == "ko" {
            return summaryKey
        }
        return String.localizedStringWithFormat(
            AppLanguage.localized("%@ 관점으로 차트 근거와 무효화 조건을 검증합니다."),
            localizedTitle
        )
    }

    var localizationTitleKey: String {
        switch self {
        case .trendFollowing: "추세 추종"
        case .swingStructure: "스윙 구조"
        case .breakoutRetest: "돌파·재시험"
        case .supportResistance: "지지·저항"
        case .candlestick: "캔들 패턴"
        case .momentum: "모멘텀"
        case .meanReversion: "평균 회귀"
        case .volatilityBreakout: "변동성 돌파"
        case .volumePriceAction: "거래량·가격행동"
        case .movingAverage: "이동평균"
        case .divergence: "다이버전스"
        case .marketStructure: "시장 구조"
        case .liquiditySweep: "유동성 스윕"
        case .falseBreakout: "페이크아웃"
        case .riskInvalidation: "리스크·무효화"
        case .riskReward: "손익비 우선"
        case .reversal: "추세 전환"
        case .rangeTrading: "범위 매매"
        case .pullback: "눌림목·되돌림"
        case .contrarian: "역발상·반대 시나리오"
        }
    }

    private var summaryKey: String {
        switch self {
        case .trendFollowing: "큰 방향과 같은 쪽의 지속 조건을 우선합니다."
        case .swingStructure: "고점·저점 배열로 추세 지속과 전환을 구분합니다."
        case .breakoutRetest: "경계 돌파 뒤 재시험과 거부 반응을 확인합니다."
        case .supportResistance: "반복 반응한 지지·저항을 판단 기준으로 둡니다."
        case .candlestick: "몸통·꼬리·연속 캔들의 완성도를 비교합니다."
        case .momentum: "진행 속도와 캔들 확장으로 힘의 우위를 봅니다."
        case .meanReversion: "과도한 이탈 뒤 평균 구간 복귀 가능성을 봅니다."
        case .volatilityBreakout: "압축 뒤 변동성 확장과 후속 진행을 확인합니다."
        case .volumePriceAction: "보이는 거래량과 가격 진행의 일치 여부를 봅니다."
        case .movingAverage: "화면에 표시된 평균선의 방향과 재접촉을 봅니다."
        case .divergence: "가격 진행과 보이는 힘의 불일치를 경계합니다."
        case .marketStructure: "범위·추세·전환 국면을 구조적으로 분류합니다."
        case .liquiditySweep: "고점·저점 훼손 뒤 빠른 복귀를 유동성 신호로 봅니다."
        case .falseBreakout: "돌파 실패와 재진입이 기존 판단을 뒤집는지 봅니다."
        case .riskInvalidation: "진입보다 먼저 판단이 틀리는 가격 조건을 정합니다."
        case .riskReward: "손절 대비 목표 공간이 충분한 기회만 남깁니다."
        case .reversal: "기존 추세가 끝났다는 확인 조건을 엄격히 봅니다."
        case .rangeTrading: "박스 상·하단 반응과 중앙 구간의 불리함을 봅니다."
        case .pullback: "추격 대신 되돌림 구간의 재개 신호를 기다립니다."
        case .contrarian: "주된 결론을 무효화할 반대 시나리오부터 검증합니다."
        }
    }
}

enum AgentConceptMockCopy {
    static func homeRemark(for concept: InvestmentConcept) -> String {
        concept.localizedSummary
    }

    static func analysisRemark(for concept: InvestmentConcept, stage: AnalysisStage) -> String {
        "\(concept.localizedSummary) · \(stage.title)"
    }

    static func responseWaitingRemark(for concept: InvestmentConcept) -> String {
        String.localizedStringWithFormat(
            AppLanguage.localized("%@ 관점의 근거를 정리하는 중…"),
            concept.localizedTitle
        )
    }

    static func concept(for agentID: String) -> InvestmentConcept {
        if let customized = AgentProfileStore.shared.profile(for: agentID)?.concept {
            return customized
        }
        if let base = PixelAgent.defaultTeam.first(where: { $0.id == agentID }) {
            return AgentProfile.defaultProfile(for: base).concept
        }
        return .swingStructure
    }
}

struct AgentAppearance: Identifiable, Codable, Equatable {
    let id: String
    let assetName: String
    let title: String
    let accentHex: String

    var localizedTitle: String { AppLanguage.localized(title) }
    var accent: Color { Color(hex: accentHex) }

    static let all: [AgentAppearance] = [
        .init(id: "default_trendy", assetName: "AgentTrendyAtlas", title: "블루 바이저", accentHex: "2DE8B1"),
        .init(id: "default_patty", assetName: "AgentPattyAtlas", title: "바이올렛 보브", accentHex: "9B87FF"),
        .init(id: "default_momo", assetName: "AgentMomoAtlas", title: "터쿼이즈 헤드셋", accentHex: "5795FF"),
        .init(id: "default_gadi", assetName: "AgentGadiAtlas", title: "필드 가디언", accentHex: "FFB23F"),
        .init(id: "default_devil", assetName: "AgentDevilAtlas", title: "화이트 데빌", accentHex: "FF587A"),
        .init(id: "neo_quant", assetName: "AgentNeoQuantAtlas", title: "네오 퀀트", accentHex: "A970FF"),
        .init(id: "classic_strategist", assetName: "AgentClassicStrategistAtlas", title: "클래식 전략가", accentHex: "75C36A")
    ]

    static func appearance(id: String) -> AgentAppearance? {
        all.first { $0.id == id }
    }
}

enum AgentProfileError: LocalizedError, Equatable {
    case invalidRole
    case invalidName
    case invalidTone
    case invalidAppearance
    case duplicateConcept

    var errorDescription: String? {
        switch self {
        case .invalidRole: AppLanguage.localized("지원하지 않는 에이전트 역할입니다.")
        case .invalidName: AppLanguage.localized("이름은 1~10자이며 줄바꿈을 포함할 수 없습니다.")
        case .invalidTone: AppLanguage.localized("말투는 1~20자이며 줄바꿈을 포함할 수 없습니다.")
        case .invalidAppearance: AppLanguage.localized("지원하지 않는 외형입니다.")
        case .duplicateConcept: AppLanguage.localized("다른 에이전트가 이미 사용 중인 판단 컨셉입니다.")
        }
    }
}

struct AgentProfile: Codable, Equatable, Identifiable {
    static let schemaVersion = 1
    let version: Int
    let roleID: String
    let displayName: String
    let tone: String
    let concept: InvestmentConcept
    let appearanceID: String

    var id: String { roleID }

    var localizedDisplayName: String {
        guard let defaultAgent = PixelAgent.defaultTeam.first(where: { $0.id == roleID }),
              displayName == defaultAgent.name else { return displayName }
        return defaultAgent.localizedName
    }

    var localizedTone: String {
        tone == "간결하고 단호하게" ? AppLanguage.localized(tone) : tone
    }

    func storageDisplayName(from editorValue: String) -> String {
        guard let defaultAgent = PixelAgent.defaultTeam.first(where: { $0.id == roleID }),
              displayName == defaultAgent.name,
              editorValue == defaultAgent.localizedName else { return editorValue }
        return defaultAgent.name
    }

    func storageTone(from editorValue: String) -> String {
        guard tone == "간결하고 단호하게",
              editorValue == AppLanguage.localized(tone) else { return editorValue }
        return tone
    }

    static func canonicalDisplayName(_ value: String, roleID: String) -> String {
        guard let defaultAgent = PixelAgent.defaultTeam.first(where: { $0.id == roleID }) else {
            return value
        }
        let legacyEnglishNames = [
            "trend": "Trendy",
            "pattern": "Patty",
            "momentum": "Momo",
            "risk": "Gadi",
            "devil": "Devil",
        ]
        let isDefaultName = localizedValues(for: defaultAgent.name).contains(value)
            || legacyEnglishNames[roleID] == value
        return isDefaultName ? defaultAgent.name : value
    }

    static func canonicalTone(_ value: String) -> String {
        let isDefaultTone = localizedValues(for: "간결하고 단호하게").contains(value)
            || value == "Brief and decisive"
        return isDefaultTone ? "간결하고 단호하게" : value
    }

    private static func localizedValues(for key: String) -> Set<String> {
        Set(AppLanguage.allCases.map { language in
            String(localized: String.LocalizationValue(key), locale: language.locale)
        })
    }

    init(
        version: Int = schemaVersion,
        roleID: String,
        displayName: String,
        tone: String,
        concept: InvestmentConcept,
        appearanceID: String
    ) throws {
        let allowedRoles = Set(PixelAgent.defaultTeam.map(\.id))
        guard allowedRoles.contains(roleID) else { throw AgentProfileError.invalidRole }
        guard Self.isValid(displayName, maximum: 10) else { throw AgentProfileError.invalidName }
        guard Self.isValid(tone, maximum: 20) else { throw AgentProfileError.invalidTone }
        guard AgentAppearance.appearance(id: appearanceID) != nil else { throw AgentProfileError.invalidAppearance }
        self.version = version
        self.roleID = roleID
        self.displayName = displayName.trimmingCharacters(in: .whitespaces)
        self.tone = tone.trimmingCharacters(in: .whitespaces)
        self.concept = concept
        self.appearanceID = appearanceID
    }

    static func defaultProfile(for agent: PixelAgent) -> AgentProfile {
        let concept: InvestmentConcept
        switch agent.id {
        case "trend": concept = .swingStructure
        case "pattern": concept = .candlestick
        case "momentum": concept = .momentum
        case "risk": concept = .riskInvalidation
        default: concept = .falseBreakout
        }
        return try! AgentProfile(
            roleID: agent.id,
            displayName: agent.name,
            tone: "간결하고 단호하게",
            concept: concept,
            appearanceID: "default_\(agent.id == "pattern" ? "patty" : agent.id == "momentum" ? "momo" : agent.id == "risk" ? "gadi" : agent.id == "devil" ? "devil" : "trendy")"
        )
    }

    private static func isValid(_ value: String, maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
            && trimmed.count <= maximum
            && trimmed.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}

struct AgentProfileSnapshot: Codable, Equatable, Identifiable {
    let roleID: String
    let displayName: String
    let tone: String
    let concept: InvestmentConcept
    let appearanceID: String

    // JSONDecoder.convertFromSnakeCase normalizes `role_id` to `roleId`, not
    // `roleID`. Keep acronym-backed properties explicit so server snapshots
    // round-trip without weakening the Swift naming used by the app.
    private enum CodingKeys: String, CodingKey {
        case roleID = "roleId"
        case displayName
        case tone
        case concept
        case appearanceID = "appearanceId"
    }

    var id: String { roleID }

    init(_ profile: AgentProfile) {
        roleID = profile.roleID
        displayName = profile.localizedDisplayName
        tone = profile.localizedTone
        concept = profile.concept
        appearanceID = profile.appearanceID
    }

    var profile: AgentProfile? {
        try? AgentProfile(
            roleID: roleID,
            displayName: AgentProfile.canonicalDisplayName(displayName, roleID: roleID),
            tone: AgentProfile.canonicalTone(tone),
            concept: concept,
            appearanceID: appearanceID
        )
    }

    var localizedForRequest: AgentProfileSnapshot {
        guard let profile else { return self }
        return AgentProfileSnapshot(profile)
    }
}

final class AgentProfileStore: ObservableObject {
    static let shared = AgentProfileStore()

    @Published private(set) var profiles: [AgentProfile]
    private let defaults: UserDefaults
    private let storageKey = "agentProfiles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        profiles = Self.load(from: defaults) ?? PixelAgent.defaultTeam.map(AgentProfile.defaultProfile)
    }

    var agents: [PixelAgent] {
        PixelAgent.defaultTeam.map { base in
            guard let profile = profile(for: base.id) else { return base }
            return base.applying(profile)
        }
    }

    var snapshots: [AgentProfileSnapshot] { profiles.map(AgentProfileSnapshot.init) }

    func profile(for roleID: String) -> AgentProfile? {
        profiles.first { $0.roleID == roleID }
    }

    func isConceptAvailable(_ concept: InvestmentConcept, excluding roleID: String) -> Bool {
        !profiles.contains { $0.roleID != roleID && $0.concept == concept }
    }

    func saveUnique(_ profile: AgentProfile) throws {
        guard isConceptAvailable(profile.concept, excluding: profile.roleID) else {
            throw AgentProfileError.duplicateConcept
        }
        save(profile)
    }

    func save(_ profile: AgentProfile) {
        profiles.removeAll { $0.roleID == profile.roleID }
        profiles.append(profile)
        profiles.sort { Self.roleIndex($0.roleID) < Self.roleIndex($1.roleID) }
        persist()
    }

    func reset(roleID: String) {
        guard let base = PixelAgent.defaultTeam.first(where: { $0.id == roleID }) else { return }
        save(AgentProfile.defaultProfile(for: base))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [AgentProfile]? {
        guard let data = defaults.data(forKey: "agentProfiles.v1"),
              let decoded = try? JSONDecoder().decode([AgentProfile].self, from: data),
              Set(decoded.map(\.roleID)) == Set(PixelAgent.defaultTeam.map(\.id)) else { return nil }

        let migrated = decoded.compactMap { profile in
            try? AgentProfile(
                version: profile.version,
                roleID: profile.roleID,
                displayName: AgentProfile.canonicalDisplayName(profile.displayName, roleID: profile.roleID),
                tone: AgentProfile.canonicalTone(profile.tone),
                concept: profile.concept,
                appearanceID: profile.appearanceID
            )
        }
        guard migrated.count == decoded.count else { return nil }

        if migrated != decoded, let migratedData = try? JSONEncoder().encode(migrated) {
            defaults.set(migratedData, forKey: "agentProfiles.v1")
        }
        return migrated
    }

    private static func roleIndex(_ roleID: String) -> Int {
        PixelAgent.defaultTeam.firstIndex { $0.id == roleID } ?? .max
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
