import AppTrackingTransparency
import Airbridge
import Foundation

@MainActor
final class AttributionService {
    static let shared = AttributionService()

    private(set) var isConfigured = false
    private var didRequestTrackingAuthorization = false

    private init() {}

    func configure() {
        if !isConfigured,
           let appName = infoValue(forKey: "AirbridgeAppName"),
           let token = infoValue(forKey: "AirbridgeSDKToken"),
           isUsable(appName),
           isUsable(token) {
            let option = AirbridgeOptionBuilder(name: appName, token: token)
                .setAutoDetermineTrackingAuthorizationTimeout(second: 30)
                // TikTok is the only SDK allowed to update SKAN conversion
                // values. Airbridge is retained for the organic profile link.
                .setTrackingBlocklist([.skAdNetwork])
                .build()
            Airbridge.initializeSDK(option: option)
            isConfigured = true
        }

        PaidAdsTrackingService.shared.configure()
    }

    func requestTrackingAuthorizationIfNeeded() async {
        configure()
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
              !didRequestTrackingAuthorization else {
            return
        }

        didRequestTrackingAuthorization = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }

    func track(_ event: Event, properties: [String: Any] = [:]) {
        configure()

        if isConfigured {
            Airbridge.trackEvent(
                category: event.rawValue,
                semanticAttributes: [:],
                customAttributes: properties
            )
        }
        PaidAdsTrackingService.shared.track(event, properties: properties)
    }

    enum Event: String {
        case onboardingCompleted = "chartagent_onboarding_completed"
        case analysisStarted = "chartagent_analysis_started"
        case analysisCompleted = "chartagent_analysis_completed"
        case analysisFailed = "chartagent_analysis_failed"
        case subscriptionStarted = "chartagent_subscription_started"
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
