import Foundation
import RevenueCat

enum RevenueCatConfig {
    static let proEntitlementIdentifier = "pro"
    static let sixMonthProductIdentifier = "ai.chartagent.ios.pro.6month"
    static let weeklyProductIdentifier = "ai.chartagent.ios.pro.weekly"

    static let paywallProductIdentifiers: Set<String> = [
        sixMonthProductIdentifier,
        weeklyProductIdentifier
    ]

    static func paywallPriority(for productIdentifier: String) -> Int {
        switch productIdentifier {
        case sixMonthProductIdentifier: 0
        case weeklyProductIdentifier: 1
        default: 2
        }
    }

    static var publicAPIKey: String {
        let environmentValue = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"]
        let infoValue = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
        return (environmentValue ?? infoValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasValidPublicAPIKey: Bool {
        let key = publicAPIKey
        return !key.contains("$(") && (key.hasPrefix("appl_") || key.hasPrefix("test_"))
    }

    @discardableResult
    static func configureIfPossible() -> Bool {
        guard hasValidPublicAPIKey else { return false }
        guard !Purchases.isConfigured else { return true }

#if DEBUG
        Purchases.logLevel = .debug
#else
        Purchases.logLevel = .warn
#endif
        Purchases.configure(withAPIKey: publicAPIKey)
        return true
    }
}
