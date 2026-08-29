import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"
    static let didChangeNotification = Notification.Name("ChartAgent.AppLanguageDidChange")

    case system
    case english
    case korean
    case japanese
    case german
    case frenchFrance
    case spanishMexico
    case portugueseBrazil
    case chineseTraditional
    case indonesian
    case thai
    case chineseSimplified
    case vietnamese
    case italian
    case turkish
    case spanishSpain
    case frenchCanada

    var id: Self { self }

    var locale: Locale {
        Locale(identifier: localizationIdentifier)
    }

    private var localizationIdentifier: String {
        switch self {
        case .system:
            let identifier = Self.supportedLocaleIdentifier(Locale.autoupdatingCurrent.identifier)
            if identifier == "en-US" { return "en" }
            if identifier == "fr-FR" { return "fr" }
            if identifier == "es-ES" { return "es" }
            return identifier
        case .english:
            return "en"
        case .frenchFrance:
            return "fr"
        case .spanishSpain:
            return "es"
        default:
            return responseLanguage
        }
    }

    var responseLanguage: String {
        switch self {
        case .system:
            return Self.supportedLocaleIdentifier(Locale.autoupdatingCurrent.identifier)
        case .english:
            return "en-US"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        case .german:
            return "de"
        case .frenchFrance:
            return "fr-FR"
        case .spanishMexico:
            return "es-MX"
        case .portugueseBrazil:
            return "pt-BR"
        case .chineseTraditional:
            return "zh-Hant"
        case .indonesian:
            return "id"
        case .thai:
            return "th"
        case .chineseSimplified:
            return "zh-Hans"
        case .vietnamese:
            return "vi"
        case .italian:
            return "it"
        case .turkish:
            return "tr"
        case .spanishSpain:
            return "es-ES"
        case .frenchCanada:
            return "fr-CA"
        }
    }

    var title: String {
        switch self {
        case .system:
            return Self.localized("시스템 언어", defaultValue: "시스템 언어")
        case .english:
            return "English (United States)"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        case .german:
            return "Deutsch"
        case .frenchFrance:
            return "Français (France)"
        case .spanishMexico:
            return "Español (México)"
        case .portugueseBrazil:
            return "Português (Brasil)"
        case .chineseTraditional:
            return "繁體中文"
        case .indonesian:
            return "Bahasa Indonesia"
        case .thai:
            return "ไทย"
        case .chineseSimplified:
            return "简体中文"
        case .vietnamese:
            return "Tiếng Việt"
        case .italian:
            return "Italiano"
        case .turkish:
            return "Türkçe"
        case .spanishSpain:
            return "Español (España)"
        case .frenchCanada:
            return "Français (Canada)"
        }
    }

    static var current: Self {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? Self.system.rawValue
        return Self(rawValue: stored) ?? .system
    }

    static func select(_ language: Self) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: language.rawValue
        )
    }

    static func select(rawValue: String) {
        select(Self(rawValue: rawValue) ?? .system)
    }

    static func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            bundle: localizationBundle,
            locale: current.locale
        )
    }

    static func localized(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            bundle: localizationBundle,
            locale: current.locale
        )
    }

    private static var localizationBundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: current.localizationIdentifier,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    static func supportedLocaleIdentifier(_ identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()

        if normalized.hasPrefix("ko") { return "ko" }
        if normalized.hasPrefix("ja") { return "ja" }
        if normalized.hasPrefix("de") { return "de" }
        if normalized.hasPrefix("fr-ca") { return "fr-CA" }
        if normalized.hasPrefix("fr") { return "fr-FR" }
        if normalized.hasPrefix("es-mx") { return "es-MX" }
        if normalized.hasPrefix("es") { return "es-ES" }
        if normalized.hasPrefix("pt") { return "pt-BR" }
        if normalized.hasPrefix("zh") {
            let usesTraditional = normalized.contains("hant")
                || normalized.contains("-tw")
                || normalized.contains("-hk")
                || normalized.contains("-mo")
            return usesTraditional ? "zh-Hant" : "zh-Hans"
        }
        if normalized.hasPrefix("id") { return "id" }
        if normalized.hasPrefix("th") { return "th" }
        if normalized.hasPrefix("vi") { return "vi" }
        if normalized.hasPrefix("it") { return "it" }
        if normalized.hasPrefix("tr") { return "tr" }
        return "en-US"
    }
}

enum MarketLanguage {
    static func stanceLabel(_ code: String) -> String {
        switch normalizedStanceCode(code) {
        case "bullish":
            AppLanguage.localized("market.stance.bullish", defaultValue: "매수")
        case "bearish":
            AppLanguage.localized("market.stance.bearish", defaultValue: "매도")
        default:
            AppLanguage.localized("market.stance.observe", defaultValue: "관망")
        }
    }

    static func normalizedStanceCode(_ code: String) -> String {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "bullish", "buy", "buy_side", "buy-side":
            return "bullish"
        case "bearish", "sell", "sell_side", "sell-side":
            return "bearish"
        case "neutral", "wait", "observe", "hold":
            return "observe"
        default:
            if normalized.contains("매수") || normalized.contains("상방") || normalized.contains("bull") {
                return "bullish"
            } else if normalized.contains("매도") || normalized.contains("하방") || normalized.contains("bear") {
                return "bearish"
            } else if normalized.contains("중립") || normalized.contains("neutral") || normalized.contains("관망") {
                return "observe"
            } else {
                return "observe"
            }
        }
    }

    static func symbolLabel(_ symbol: MarketSymbol) -> String {
        let code = symbol.code.split(separator: ":").last.map(String.init) ?? symbol.code
        return code.isEmpty ? symbol.name : code
    }

    static func historyTimestamp(_ date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return AppLanguage.localized("history.time.just_now", defaultValue: "방금 전")
        }
        if elapsed < 86_400 {
            let totalMinutes = Int64(elapsed / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                let format = AppLanguage.localized("history.time.hours_minutes_ago", defaultValue: "%1$lld시간 %2$lld분 전")
                return String.localizedStringWithFormat(format, hours, minutes)
            }
            let format = AppLanguage.localized("history.time.minutes_ago", defaultValue: "%lld분 전")
            return String.localizedStringWithFormat(format, minutes)
        }

        let formatted = date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(AppLanguage.current.locale)
        )
        let format = AppLanguage.localized("history.time.absolute", defaultValue: "%@")
        return String.localizedStringWithFormat(format, formatted)
    }

    static func recordStrategy(_ record: AnalysisRecord) -> String {
        let scenarioAction = record.result.scenarios
            .map(\.action)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return localizedTerms(in: scenarioAction ?? record.result.consensus.summary)
    }

    static func localizedTerms(in source: String) -> String {
        let replacements = [
            (#"(?i)\bbuy[\s-]*side\b"#, AppLanguage.localized("market.term.buy_side", defaultValue: "매수")),
            (#"(?i)\bsell[\s-]*side\b"#, AppLanguage.localized("market.term.sell_side", defaultValue: "매도")),
            (#"(?i)\bwait\b"#, AppLanguage.localized("market.term.wait", defaultValue: "관망"))
        ]

        return replacements.reduce(source) { text, replacement in
            text.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: .regularExpression
            )
        }
    }

    static func compactStructureValue(in source: String) -> String {
        let localized = localizedTerms(in: source)
        guard AppLanguage.current.responseLanguage.hasPrefix("en") else { return localized }
        return localized.replacingOccurrences(
            of: #"(?i)^approximately\s+"#,
            with: "Approx. ",
            options: .regularExpression
        )
    }
}
