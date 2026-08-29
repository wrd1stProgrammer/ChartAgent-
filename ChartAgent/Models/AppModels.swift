import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case history
    case agents
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .home: AppLanguage.localized("홈")
        case .history: AppLanguage.localized("분석 기록")
        case .agents: AppLanguage.localized("에이전트")
        case .profile: AppLanguage.localized("마이")
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .history: "chart.xyaxis.line"
        case .agents: "cpu.fill"
        case .profile: "person.fill"
        }
    }
}

struct OnboardingProfile {
    var name = ""
    var experience = TradingExperience.intermediate
    var market = MarketFocus.crypto
    var style = TradingStyle.swing
    var challenge = TradingChallenge.entries
}

protocol TradingChoice: CaseIterable, Hashable, Identifiable {
    var title: String { get }
    var subtitle: String { get }
    var icon: String { get }
}

extension TradingChoice where Self: RawRepresentable, Self.RawValue == String {
    var id: String { rawValue }
}

enum TradingExperience: String, TradingChoice {
    case beginner, intermediate, experienced, pro

    var title: String { AppLanguage.localized(["입문", "중급", "숙련", "프로"][index]) }
    var subtitle: String { AppLanguage.localized(["이제 막 차트를 보기 시작했어요", "실전 매매를 경험하고 있어요", "여러 해 동안 꾸준히 거래했어요", "트레이딩이 주업이에요"][index]) }
    var icon: String { ["leaf.fill", "chart.bar.fill", "bolt.fill", "crown.fill"][index] }
    private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

enum MarketFocus: String, TradingChoice {
    case crypto, stocks, forex, futures

    var title: String { AppLanguage.localized(["가상자산", "주식", "외환", "선물"][index]) }
    var subtitle: String { AppLanguage.localized(["BTC · ETH · 알트코인", "국내외 개별 종목", "주요 통화쌍", "지수 · 원자재 선물"][index]) }
    var icon: String { ["bitcoinsign.circle.fill", "building.columns.fill", "dollarsign.arrow.circlepath", "waveform.path.ecg"][index] }
    private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

enum TradingStyle: String, TradingChoice {
    case scalping, day, swing, position, flexible

    var title: String { AppLanguage.localized(["스캘핑", "데이 트레이딩", "스윙 트레이딩", "포지션 트레이딩", "딱히 정하지 않았어요"][index]) }
    var subtitle: String { AppLanguage.localized(["수초에서 수분 단위", "당일 흐름에 집중", "수일에서 수주 보유", "큰 추세를 길게 추적", "차트에 맞는 시간축을 추천받을래요"][index]) }
    var icon: String { ["hare.fill", "sun.max.fill", "waveform", "calendar", "sparkles"][index] }
    private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

enum TradingChallenge: String, TradingChoice {
    case entries, exits, risk, emotion, confluence

    var title: String { AppLanguage.localized(["진입", "청산", "리스크", "감정 매매", "근거 종합"][index]) }
    var subtitle: String { AppLanguage.localized(["언제 들어갈지 어려워요", "적절한 청산 시점을 놓쳐요", "손절과 비중 관리가 어려워요", "FOMO와 추격 매매를 해요", "전체 그림을 읽고 싶어요"][index]) }
    var icon: String { ["scope", "flag.checkered", "shield.lefthalf.filled", "flame.fill", "square.grid.2x2.fill"][index] }
    private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
