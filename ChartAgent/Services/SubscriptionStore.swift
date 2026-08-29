import Foundation
import RevenueCat

@MainActor
final class SubscriptionStore: ObservableObject {
    enum PurchaseOutcome {
        case purchased
        case cancelled
    }

    @Published private(set) var packages: [Package] = []
    @Published private(set) var isLoadingPrices = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var isProActive = false
    @Published private(set) var isEntitlementResolved = false
    @Published private(set) var loadErrorMessage: String?

    var isBusy: Bool {
        isLoadingPrices || isPurchasing || isRestoring
    }

    func refreshEntitlement() async {
        guard RevenueCatConfig.configureIfPossible() else {
            isProActive = false
            isEntitlementResolved = true
            return
        }

        do {
            _ = apply(try await Purchases.shared.customerInfo())
        } catch {
            isProActive = false
            isEntitlementResolved = true
        }
    }

    @discardableResult
    func loadPaywall() async -> Bool {
        guard RevenueCatConfig.configureIfPossible() else {
            packages = []
            loadErrorMessage = SubscriptionError.missingPublicKey.localizedDescription
            isEntitlementResolved = true
            return false
        }

        isLoadingPrices = true
        loadErrorMessage = nil
        defer {
            isLoadingPrices = false
            isEntitlementResolved = true
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                throw SubscriptionError.missingCurrentOffering
            }

            let availablePackages = offering.availablePackages
                .filter {
                    RevenueCatConfig.paywallProductIdentifiers.contains($0.storeProduct.productIdentifier)
                }
                .sorted {
                    RevenueCatConfig.paywallPriority(for: $0.storeProduct.productIdentifier)
                        < RevenueCatConfig.paywallPriority(for: $1.storeProduct.productIdentifier)
                }
            guard !availablePackages.isEmpty else {
                throw SubscriptionError.missingPackages
            }

            packages = availablePackages
            do {
                return apply(try await Purchases.shared.customerInfo())
            } catch {
                // Entitlement refresh and product loading are independent.
                // Keep valid StoreKit products purchasable when only the
                // customer-info request has a transient network failure.
                return isProActive
            }
        } catch {
            packages = []
            loadErrorMessage = error.localizedDescription
            return false
        }
    }

    func purchase(_ package: Package) async throws -> PurchaseOutcome {
        guard RevenueCatConfig.configureIfPossible() else {
            throw SubscriptionError.missingPublicKey
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            return .cancelled
        }

        guard apply(result.customerInfo) else {
            throw SubscriptionError.entitlementNotActivated
        }

        let product = package.storeProduct
        let currency = product.currencyCode ?? "USD"
        AttributionService.shared.track(
            .subscriptionStarted,
            properties: [
                "product_id": product.productIdentifier,
                "value": NSDecimalNumber(decimal: product.price).doubleValue,
                "currency": currency
            ]
        )
        return .purchased
    }

    @discardableResult
    func restore() async throws -> Bool {
        guard RevenueCatConfig.configureIfPossible() else {
            throw SubscriptionError.missingPublicKey
        }

        isRestoring = true
        defer { isRestoring = false }

        return apply(try await Purchases.shared.restorePurchases())
    }

    func package(withIdentifier identifier: String?) -> Package? {
        guard let identifier else { return nil }
        return packages.first { $0.identifier == identifier }
    }

    private func apply(_ customerInfo: CustomerInfo) -> Bool {
        let isActive = customerInfo.entitlements[RevenueCatConfig.proEntitlementIdentifier]?.isActive == true
        isProActive = isActive
        isEntitlementResolved = true
        return isActive
    }

}

private enum SubscriptionError: LocalizedError {
    case missingPublicKey
    case missingCurrentOffering
    case missingPackages
    case entitlementNotActivated

    var errorDescription: String? {
        switch self {
        case .missingPublicKey:
#if DEBUG
            AppLanguage.localized("RevenueCat Apple public SDK key가 없습니다. Config/Secrets.xcconfig를 확인해 주세요.")
#else
            AppLanguage.localized("구매 정보를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요.")
#endif
        case .missingCurrentOffering:
            AppLanguage.localized("현재 판매 중인 구독 상품을 찾을 수 없습니다.")
        case .missingPackages:
            AppLanguage.localized("표시할 구독 상품이 없습니다. RevenueCat Offering 구성을 확인해 주세요.")
        case .entitlementNotActivated:
            AppLanguage.localized("결제는 확인됐지만 PRO 권한을 활성화하지 못했습니다. 구매 복원을 시도해 주세요.")
        }
    }
}
