import Foundation

struct AnalysisDraft: Equatable, Identifiable {
    let id = UUID()
    let imageData: Data
    let includesNews: Bool
    let activeAgentIDs: [String]
    let agentProfiles: [AgentProfile]
}

struct MarketSymbol: Codable, Equatable, Identifiable {
    let code: String
    let name: String
    let instrumentType: String

    var id: String { code }
}

struct NewsReference: Codable, Equatable, Identifiable {
    let title: String
    let source: String
    let publishedAt: Int
    let url: URL?
    let relatedSymbols: [String]
    let relevance: String

    var id: String { "\(publishedAt)-\(source)-\(title)" }
    var date: Date {
        let seconds = publishedAt > 10_000_000_000 ? publishedAt / 1_000 : publishedAt
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

struct ChartValidationResult: Codable, Equatable {
    let isChart: Bool
    let isReadable: Bool
    let detectedSymbol: String?
    let detectedTimeframe: String?
    let reasonCode: String
    let message: String
}

struct ConsensusResult: Codable, Equatable {
    let title: String
    let stanceCode: String
    let confidence: Int
    let summary: String
}

struct AnalysisScopeResult: Codable, Equatable {
    let visible: [String]
    let unavailable: [String]
}

struct AgentOpinion: Codable, Equatable, Identifiable {
    let agentId: String
    let stanceCode: String?
    let stance: String
    let confidence: Int
    let thesis: String
    let evidence: [String]

    var id: String { agentId }
}

struct AnalysisScenario: Codable, Equatable, Identifiable {
    let title: String
    let condition: String
    let action: String
    let tone: String

    var id: String { "\(title)-\(condition)" }
}

struct StructureLevel: Codable, Equatable, Identifiable {
    let label: String
    let value: String
    let note: String
    let tone: String

    var id: String { "\(label)-\(value)" }
}

struct MeetingLine: Codable, Equatable, Identifiable {
    let stage: String
    let agentId: String
    let bubble: String
    let log: String

    var id: String { "\(stage)-\(agentId)-\(bubble)" }
}

struct DataQualityResult: Codable, Equatable {
    let chart: String
    let priceAxis: String
    let timeframe: String
    let news: String
}

struct NewsImpactResult: Codable, Equatable {
    let collectedCount: Int
    let usedCount: Int
    let effect: String
    let summary: String
    let usedTitles: [String]
}

struct TradePlanResult: Codable, Equatable {
    let directionCode: String
    let referencePrice: String
    let entry: String
    let stop: String
    let target: String
    let riskReward: String
    let trigger: String
    let rationale: String
}

struct AnalysisPayload: Codable, Equatable {
    let validation: ChartValidationResult
    let consensus: ConsensusResult
    let scope: AnalysisScopeResult
    let agentOpinions: [AgentOpinion]
    let scenarios: [AnalysisScenario]
    let structure: [StructureLevel]
    let meetingScript: [MeetingLine]
    let dataQuality: DataQualityResult
    let newsImpact: NewsImpactResult?
    let tradePlan: TradePlanResult?
    let followUpSuggestions: [String]
}

struct AnalysisRecord: Codable, Equatable, Identifiable {
    let id: String
    let createdAt: Date
    let provider: String
    let symbol: MarketSymbol
    let timeframe: String
    let includedNews: Bool
    let result: AnalysisPayload
    let news: [NewsReference]
    let agentProfiles: [AgentProfileSnapshot]?
}

struct FollowUpResponse: Codable, Equatable {
    let agentId: String
    let answer: String
    let caveat: String
    let provider: String
}

struct FollowUpHistoryItem: Codable, Equatable {
    let agentId: String
    let question: String
    let answer: String
}

struct SavedFollowUpTurn: Codable, Equatable, Identifiable {
    let id: UUID
    let analysisId: String
    let agentId: String
    let question: String
    let answer: String
    let caveat: String
    let provider: String
    let createdAt: Date
}

struct APIErrorPayload: Codable, Equatable {
    let code: String
    let message: String
    let recovery: String?
}

struct SymbolSearchPayload: Codable {
    let symbols: [MarketSymbol]
}

enum AnalysisFailureKind: Equatable {
    case invalidImage
    case invalidChart
    case aiResponse
    case server
    case network
    case malformedResponse
}

enum ChartAgentAPIError: LocalizedError, Equatable {
    case invalidResponse
    case transport(String)
    case server(APIErrorPayload)

    var failureKind: AnalysisFailureKind {
        switch self {
        case .invalidResponse:
            .malformedResponse
        case .transport:
            .network
        case let .server(payload):
            if Self.imageInputErrorCodes.contains(payload.code) {
                .invalidImage
            } else if Self.chartReadingErrorCodes.contains(payload.code) {
                .invalidChart
            } else if payload.code == "analysis_unavailable" {
                .aiResponse
            } else {
                .server
            }
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            AppLanguage.localized("서버 응답을 읽지 못했습니다.")
        case .transport:
            AppLanguage.localized("네트워크 오류가 발생했습니다.")
        case let .server(payload):
            if payload.code == "internal_error" || payload.code.hasPrefix("http_5") {
                AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다.")
            } else {
                Self.localizedServerMessage(payload)
            }
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            AppLanguage.localized("잠시 후 다시 시도해 주세요.")
        case .transport:
            AppLanguage.localized("네트워크 연결을 확인한 뒤 다시 시도해 주세요.")
        case let .server(payload):
            if payload.code == "internal_error" || payload.code.hasPrefix("http_5") {
                AppLanguage.localized("잠시 후 다시 시도해 주세요.")
            } else if Self.imageInputErrorCodes.contains(payload.code) {
                AppLanguage.localized("다른 차트 이미지로 다시 시도해 주세요.")
            } else if Self.chartReadingErrorCodes.contains(payload.code) {
                AppLanguage.localized("종목명, 시간대, 캔들, 가격 축이 보이는 차트 캡처를 올려 주세요.")
            } else {
                AppLanguage.localized("잠시 후 다시 시도해 주세요.")
            }
        }
    }

    private static let imageInputErrorCodes: Set<String> = [
        "invalid_image_size", "image_decode_failed", "unsupported_image", "image_too_small",
    ]

    private static let chartReadingErrorCodes: Set<String> = [
        "not_chart", "unreadable_chart", "symbol_mismatch", "missing_symbol", "missing_timeframe", "invalid_timeframe", "invalid_symbol",
    ]

    private static func localizedServerMessage(_ payload: APIErrorPayload) -> String {
        switch payload.code {
        case "invalid_image_size":
            AppLanguage.localized("이미지 크기가 허용 범위를 벗어났습니다.")
        case "image_decode_failed":
            AppLanguage.localized("이미지 파일을 읽을 수 없습니다.")
        case "unsupported_image":
            AppLanguage.localized("PNG, JPEG 또는 WEBP 이미지만 사용할 수 있습니다.")
        case "image_too_small":
            AppLanguage.localized("차트 글자를 읽기에는 이미지 해상도가 너무 낮습니다.")
        case "not_chart":
            AppLanguage.localized("금융 가격 차트 이미지인지 확인할 수 없습니다.")
        case "unreadable_chart":
            AppLanguage.localized("차트의 캔들과 글자를 선명하게 읽을 수 없습니다.")
        case "missing_symbol", "invalid_symbol", "symbol_mismatch":
            AppLanguage.localized("이미지에서 종목 심볼을 확인할 수 없습니다.")
        case "missing_timeframe", "invalid_timeframe":
            AppLanguage.localized("이미지에서 차트 시간대를 확인할 수 없습니다.")
        case "invalid_agents":
            AppLanguage.localized("분석 에이전트 구성은 서로 다른 3~5명이어야 합니다.")
        case "invalid_agent_profiles":
            AppLanguage.localized("에이전트 커스터마이징 정보를 읽을 수 없습니다.")
        case "analysis_unavailable":
            AppLanguage.localized("분석 서비스를 잠시 사용할 수 없습니다.")
        case "dependency_unavailable":
            AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다.")
        default:
            AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다.")
        }
    }
}
