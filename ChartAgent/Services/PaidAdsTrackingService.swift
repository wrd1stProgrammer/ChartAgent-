import FacebookCore
import Foundation
import TikTokBusinessSDK

/// Sends paid-media events directly to Meta and TikTok.
///
/// Airbridge remains a separate attribution path for the TikTok profile tracking
/// link. Keeping this service independent prevents the paid ad SDKs from being
/// treated as an Airbridge MMP connection.
@MainActor
final class PaidAdsTrackingService {
    static let shared = PaidAdsTrackingService()

    private var didConfigure = false
    private var isMetaConfigured = false
    private var isTikTokConfigured = false

    private init() {}

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true

        configureMeta()
        configureTikTok()
    }

    func track(_ event: AttributionService.Event, properties: [String: Any] = [:]) {
        configure()

        if isMetaConfigured {
            trackMeta(event, properties: properties)
        }
        if isTikTokConfigured {
            trackTikTok(event, properties: properties)
        }
    }

    private func configureMeta() {
        guard let appID = infoValue(forKey: "MetaAppID"),
              let clientToken = infoValue(forKey: "MetaClientToken"),
              isUsable(appID),
              isUsable(clientToken) else {
            return
        }

        // AppEvents is initialized explicitly because this app uses SwiftUI's
        // lifecycle instead of an UIApplicationDelegate.
        Settings.shared.appID = appID
        Settings.shared.clientToken = clientToken
        Settings.shared.isAutoLogAppEventsEnabled = false

        // TikTok is the single SKAN conversion-value owner for this app. Meta
        // still receives ATT-authorized app events, but does not compete for
        // SKAN conversion-value updates.
        Settings.shared.isSKAdNetworkReportEnabled = false
        ApplicationDelegate.shared.initializeSDK()
        AppEvents.shared.activateApp()
        isMetaConfigured = true
    }

    private func configureTikTok() {
        guard let accessToken = infoValue(forKey: "TikTokAccessToken"),
              let applicationID = infoValue(forKey: "TikTokApplicationID"),
              let tiktokAppID = infoValue(forKey: "TikTokAppID"),
              isUsable(accessToken),
              isUsable(applicationID),
              isUsable(tiktokAppID),
              let config = TikTokConfig(
                  accessToken: accessToken,
                  appId: applicationID,
                  tiktokAppId: tiktokAppID
              ) else {
            return
        }

        // RevenueCat owns the StoreKit purchase flow, so report the paid
        // subscription exactly once from SubscriptionStore instead of letting
        // TikTok's automatic StoreKit observer create a duplicate event.
        config.disablePaymentTracking()
        config.setDelayForATTUserAuthorizationInSeconds(30)

#if DEBUG
        config.enableDebugMode()
#endif

        // TikTok is the chosen SKAN owner. Airbridge and Meta are explicitly
        // disabled above so only one SDK updates Apple's conversion value.
        TikTokBusiness.initializeSdk(config)
        isTikTokConfigured = true
    }

    private func trackMeta(_ event: AttributionService.Event, properties: [String: Any]) {
        switch event {
        case .onboardingCompleted:
            AppEvents.shared.logEvent(.completedTutorial, parameters: metaParameters(properties))
        case .analysisStarted, .analysisCompleted, .analysisFailed:
            AppEvents.shared.logEvent(
                AppEvents.Name(event.rawValue),
                parameters: metaParameters(properties)
            )
        case .subscriptionStarted:
            let amount = numberValue(forKey: "value", in: properties)
            if let amount {
                AppEvents.shared.logEvent(
                    .subscribe,
                    valueToSum: amount,
                    parameters: metaParameters(properties)
                )
            } else {
                AppEvents.shared.logEvent(.subscribe, parameters: metaParameters(properties))
            }
        }
    }

    private func trackTikTok(_ event: AttributionService.Event, properties: [String: Any]) {
        let eventName: String
        switch event {
        case .onboardingCompleted:
            eventName = "CompleteTutorial"
        case .analysisStarted, .analysisCompleted, .analysisFailed:
            eventName = event.rawValue
        case .subscriptionStarted:
            eventName = "Subscribe"
        }

        let event = TikTokBaseEvent(
            eventName: eventName,
            properties: tiktokProperties(properties),
            eventId: nil
        )
        TikTokBusiness.trackTTEvent(event)
    }

    private func metaParameters(_ properties: [String: Any]) -> [AppEvents.ParameterName: Any] {
        properties.reduce(into: [:]) { result, entry in
            guard let value = supportedValue(entry.value) else { return }
            result[AppEvents.ParameterName(rawValue: entry.key)] = value
        }
    }

    private func tiktokProperties(_ properties: [String: Any]) -> [AnyHashable: Any] {
        properties.reduce(into: [:]) { result, entry in
            guard let value = supportedValue(entry.value) else { return }
            result[AnyHashable(entry.key)] = value
        }
    }

    private func supportedValue(_ value: Any) -> Any? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value
        case let value as Bool:
            return value
        case let value as Int:
            return value
        case let value as Double:
            return value
        case let value as Float:
            return value
        default:
            return nil
        }
    }

    private func numberValue(forKey key: String, in properties: [String: Any]) -> Double? {
        if let value = properties[key] as? Double { return value }
        if let value = properties[key] as? NSNumber { return value.doubleValue }
        if let value = properties[key] as? Int { return Double(value) }
        return nil
    }

    private func infoValue(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isUsable(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("$(") && !value.hasPrefix("REPLACE_WITH_")
    }
}
