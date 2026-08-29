import RevenueCat
import SwiftUI

enum ProPaywallTransitionPolicy {
    static func shouldCompleteAfterLoad(isProActive: Bool) -> Bool {
        false
    }
}

enum ProPaywallBackdrop: Equatable {
    case branded
    case resultLock
}

struct ProPaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    let backdrop: ProPaywallBackdrop
    let onSubscribed: () -> Void
    let onDismiss: (() -> Void)?

    @State private var selectedPackageIdentifier: String?
    @State private var alertMessage = ""
    @State private var isAlertPresented = false
    @State private var didFinish = false
    @State private var presentedLegalDocument: LegalDocumentKind?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        backdrop: ProPaywallBackdrop = .branded,
        onSubscribed: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.backdrop = backdrop
        self.onSubscribed = onSubscribed
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = PaywallMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack(alignment: .top) {
                paywallBackground(width: proxy.size.width)

                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: metrics.contentTop)

                    titleBlock(metrics: metrics)
                        .staggeredEntrance()

                    benefits(metrics: metrics)
                        .padding(.top, metrics.sectionSpacing)

                    packageList(metrics: metrics)
                        .padding(.top, metrics.sectionSpacing)

                    Spacer(minLength: metrics.minimumFooterSpacing)

                    checkoutFooter(metrics: metrics)
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom - 10, 4))
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

                Text("CHARTAGENT  PRO")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(ChartTheme.mint)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.46), in: Capsule())
                    .overlay { Capsule().stroke(ChartTheme.mint.opacity(0.26), lineWidth: 1) }
                    .padding(.top, max(proxy.safeAreaInsets.top - 28, 2))
                    .zIndex(10)

                if onDismiss != nil {
                    Button(action: dismissOnce) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                    .padding(.leading, 8)
                    .padding(.top, 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zIndex(20)
                }
            }
        }
        .background(paywallBaseColor.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await loadPaywall() }
        .alert("구매를 완료할 수 없어요", isPresented: $isAlertPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(item: $presentedLegalDocument) { kind in
            LegalDocumentSheet(kind: kind)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChartTheme.background)
        }
    }

    @ViewBuilder
    private func paywallBackground(width: CGFloat) -> some View {
        if backdrop == .branded {
            ZStack(alignment: .top) {
                Color.black

                Image("PaywallAgentsBackdrop")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: width)
                    .opacity(0.98)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.01), location: 0),
                        .init(color: .black.opacity(0.05), location: 0.24),
                        .init(color: .black.opacity(0.78), location: 0.43),
                        .init(color: .black, location: 0.57)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [ChartTheme.mint.opacity(0.12), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 430
                )
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                Color.black.opacity(0.78)
                LinearGradient(
                    colors: [.black.opacity(0.18), .black.opacity(0.92), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }

    private var paywallBaseColor: Color {
        backdrop == .branded ? .black : .clear
    }

    private func titleBlock(metrics: PaywallMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.titleSpacing) {
            Text("한 장의 차트를\n다섯 시선으로 끝까지.")
                .font(.system(size: metrics.titleSize, weight: .black))
                .tracking(-0.85)
                .foregroundStyle(.white)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)

            Text("혼자 놓치기 쉬운 신호까지, 각자 분석하고 서로 반박한 뒤 실행 가능한 결론만 남깁니다.")
                .font(.system(size: metrics.subtitleSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(2)
                .lineLimit(2)
        }
    }

    private func benefits(metrics: PaywallMetrics) -> some View {
        VStack(spacing: metrics.benefitSpacing) {
            PaywallBenefitRow(
                icon: "person.3.sequence.fill",
                title: "5인 차트 전문 에이전트 회의",
                subtitle: "추세·캔들·모멘텀·리스크·반대 시나리오를 교차검증",
                metrics: metrics
            )
            PaywallBenefitRow(
                icon: "newspaper.fill",
                title: "최신 시장 뉴스까지 연결",
                subtitle: "뉴스 반영 옵션을 켜면 차트 판단에 실제로 미친 영향까지 요약",
                metrics: metrics
            )
            PaywallBenefitRow(
                icon: "scope",
                title: "진입보다 먼저 보는 무효화 조건",
                subtitle: "현재 판단, 확인선, 방어선과 반대 전환 조건을 한 리포트로",
                metrics: metrics
            )
            PaywallBenefitRow(
                icon: "bubble.left.and.text.bubble.right.fill",
                title: "리포트 근거를 이어 묻는 후속 대화",
                subtitle: "원하는 에이전트를 골라 결과 안의 근거만 더 깊게 질문",
                metrics: metrics
            )
        }
    }

    @ViewBuilder
    private func packageList(metrics: PaywallMetrics) -> some View {
        if subscriptionStore.isLoadingPrices {
            VStack(spacing: metrics.packageSpacing) {
                PaywallPackagePlaceholder(metrics: metrics)
                PaywallPackagePlaceholder(metrics: metrics)
            }
        } else if let errorMessage = subscriptionStore.loadErrorMessage {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ChartTheme.amber)
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(ChartTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(ChartTheme.amber.opacity(0.28), lineWidth: 1) }
        } else {
            VStack(spacing: metrics.packageSpacing) {
                ForEach(Array(subscriptionStore.packages.enumerated()), id: \.element.identifier) { index, package in
                    PaywallPackageRow(
                        package: package,
                        isSelected: selectedPackageIdentifier == package.identifier,
                        isRecommended: index == 0
                            && package.storeProduct.productIdentifier == RevenueCatConfig.sixMonthProductIdentifier,
                        metrics: metrics
                    ) {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            selectedPackageIdentifier = package.identifier
                        }
                    }
                }
            }
        }
    }

    private func purchaseButton(metrics: PaywallMetrics) -> some View {
        Button(action: primaryAction) {
            HStack(spacing: 10) {
                if subscriptionStore.isLoadingPrices || subscriptionStore.isPurchasing {
                    ProgressView()
                        .tint(.black)
                        .controlSize(.small)
                }

                Text(primaryButtonTitle)
                    .font(.system(size: metrics.buttonTitleSize, weight: .black))

                if !subscriptionStore.isLoadingPrices && !subscriptionStore.isPurchasing {
                    Image(systemName: subscriptionStore.loadErrorMessage == nil ? "arrow.right" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: metrics.buttonHeight)
            .background(ChartTheme.mint.opacity(isPrimaryButtonEnabled ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: ChartTheme.mint.opacity(isPrimaryButtonEnabled ? 0.22 : 0), radius: 24, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isPrimaryButtonEnabled)
        .onboardingBeam(active: isPrimaryButtonEnabled && !reduceMotion, cornerRadius: 17)
    }

    private func checkoutFooter(metrics: PaywallMetrics) -> some View {
        VStack(spacing: 0) {
            purchaseButton(metrics: metrics)

            Text("자동 갱신 · 언제든 취소할 수 있어요")
                .font(.system(size: metrics.legalSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .padding(.top, metrics.legalSpacing)

            footer
                .padding(.top, metrics.footerSpacing)
        }
        .background {
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.96), .black],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: restorePurchases) {
                HStack(spacing: 5) {
                    if subscriptionStore.isRestoring {
                        ProgressView().controlSize(.mini).tint(.white.opacity(0.55))
                    }
                    Text(AppLanguage.localized(subscriptionStore.isRestoring ? "복원 중" : "구매 복원"))
                }
            }
            .disabled(subscriptionStore.isBusy)

            Text("·")
            Button("Terms") {
                presentedLegalDocument = .termsOfUse
            }

            Text("·")
            Button("Privacy") {
                presentedLegalDocument = .privacyPolicy
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .foregroundStyle(.white.opacity(0.38))
        .tint(.white.opacity(0.38))
        .frame(maxWidth: .infinity)
    }

    private var primaryButtonTitle: String {
        if subscriptionStore.isPurchasing { return AppLanguage.localized("구매 처리 중...") }
        if subscriptionStore.isLoadingPrices { return AppLanguage.localized("가격 불러오는 중...") }
        if subscriptionStore.isProActive { return AppLanguage.localized("ChartAgent PRO 시작하기") }
        if subscriptionStore.loadErrorMessage != nil { return AppLanguage.localized("가격 다시 불러오기") }
        return AppLanguage.localized("ChartAgent PRO 시작하기")
    }

    private var isPrimaryButtonEnabled: Bool {
        if subscriptionStore.isLoadingPrices || subscriptionStore.isPurchasing || subscriptionStore.isRestoring {
            return false
        }
        if subscriptionStore.loadErrorMessage != nil { return true }
        return subscriptionStore.isProActive || subscriptionStore.package(withIdentifier: selectedPackageIdentifier) != nil
    }

    private func loadPaywall() async {
        let isActive = await subscriptionStore.loadPaywall()
        selectDefaultPackageIfNeeded()
        if ProPaywallTransitionPolicy.shouldCompleteAfterLoad(isProActive: isActive) {
            finishOnce()
        }
    }

    private func selectDefaultPackageIfNeeded() {
        guard subscriptionStore.package(withIdentifier: selectedPackageIdentifier) == nil else { return }
        selectedPackageIdentifier = subscriptionStore.packages.first?.identifier
    }

    private func primaryAction() {
        if subscriptionStore.loadErrorMessage != nil {
            Task { await loadPaywall() }
            return
        }
        if subscriptionStore.isProActive {
            finishOnce()
            return
        }
        guard let package = subscriptionStore.package(withIdentifier: selectedPackageIdentifier) else { return }

        Task {
            do {
                if try await subscriptionStore.purchase(package) == .purchased {
                    finishOnce()
                }
            } catch {
                present(error.localizedDescription)
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                if try await subscriptionStore.restore() {
                    finishOnce()
                } else {
                    present(AppLanguage.localized("복원할 활성 PRO 구독을 찾지 못했습니다."))
                }
            } catch {
                present(error.localizedDescription)
            }
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        onSubscribed()
    }

    private func dismissOnce() {
        guard !didFinish, let onDismiss else { return }
        didFinish = true
        onDismiss()
    }

    private func present(_ message: String) {
        alertMessage = message
        isAlertPresented = true
    }
}

private struct PaywallBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let metrics: PaywallMetrics

    var body: some View {
        HStack(alignment: .top, spacing: metrics.benefitIconSpacing) {
            Image(systemName: icon)
                .font(.system(size: metrics.benefitIconSize, weight: .bold))
                .foregroundStyle(ChartTheme.mint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppLanguage.localized(title))
                    .font(.system(size: metrics.benefitTitleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                if metrics.showsBenefitSubtitles {
                    Text(AppLanguage.localized(subtitle))
                        .font(.system(size: metrics.benefitSubtitleSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PaywallPackageRow: View {
    let package: Package
    let isSelected: Bool
    let isRecommended: Bool
    let metrics: PaywallMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(isSelected ? ChartTheme.mint : .white.opacity(0.28))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(package.planTitle)
                            .font(.system(size: metrics.packageTitleSize, weight: .bold))
                            .foregroundStyle(.white)
                        if isRecommended {
                            Text("추천")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(ChartTheme.mint, in: Capsule())
                        }
                    }
                    Text(package.renewalDescription)
                        .font(.system(size: metrics.packageSubtitleSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.localizedPriceString)
                        .font(.system(size: metrics.packagePriceSize, weight: .black))
                        .foregroundStyle(.white)
                    Text(package.pricePeriodLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: metrics.packageHeight)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? ChartTheme.mint : .white.opacity(0.18), lineWidth: isSelected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PaywallPackagePlaceholder: View {
    let metrics: PaywallMetrics

    var body: some View {
        HStack(spacing: 13) {
            Circle().fill(.white.opacity(0.08)).frame(width: 23, height: 23)
            VStack(alignment: .leading, spacing: 7) {
                Capsule().fill(.white.opacity(0.10)).frame(width: 82, height: 13)
                Capsule().fill(.white.opacity(0.06)).frame(width: 126, height: 9)
            }
            Spacer()
            Capsule().fill(.white.opacity(0.10)).frame(width: 70, height: 16)
        }
        .padding(.horizontal, 15)
        .frame(height: metrics.packageHeight)
        .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}

private struct PaywallMetrics {
    let isCompact: Bool
    let contentTop: CGFloat
    let horizontalPadding: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let titleSpacing: CGFloat
    let sectionSpacing: CGFloat
    let benefitSpacing: CGFloat
    let benefitIconSpacing: CGFloat
    let benefitIconSize: CGFloat
    let benefitTitleSize: CGFloat
    let benefitSubtitleSize: CGFloat
    let showsBenefitSubtitles: Bool
    let packageSpacing: CGFloat
    let packageHeight: CGFloat
    let packageTitleSize: CGFloat
    let packageSubtitleSize: CGFloat
    let packagePriceSize: CGFloat
    let minimumFooterSpacing: CGFloat
    let buttonHeight: CGFloat
    let buttonTitleSize: CGFloat
    let legalSize: CGFloat
    let legalSpacing: CGFloat
    let footerSpacing: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        let compact = size.height < 760
        isCompact = compact
        contentTop = compact
            ? min(max(size.width * 0.42, safeAreaInsets.top + 92), 172)
            : min(max(size.width * 0.56, safeAreaInsets.top + 126), 232)
        horizontalPadding = compact ? 18 : 20
        titleSize = compact ? 25 : 30
        subtitleSize = compact ? 11.5 : 13.5
        titleSpacing = compact ? 5 : 7
        sectionSpacing = compact ? 10 : 14
        benefitSpacing = compact ? 6 : 8
        benefitIconSpacing = compact ? 10 : 12
        benefitIconSize = compact ? 14 : 15
        benefitTitleSize = compact ? 13 : 14.5
        benefitSubtitleSize = 10.5
        showsBenefitSubtitles = !compact
        packageSpacing = compact ? 7 : 8
        packageHeight = compact ? 54 : 60
        packageTitleSize = compact ? 14 : 15
        packageSubtitleSize = compact ? 10 : 11
        packagePriceSize = compact ? 16 : 18
        minimumFooterSpacing = compact ? 6 : 8
        buttonHeight = compact ? 49 : 54
        buttonTitleSize = compact ? 16 : 18
        legalSize = compact ? 10 : 11
        legalSpacing = compact ? 5 : 7
        footerSpacing = compact ? 6 : 8
    }
}

private extension Package {
    var planTitle: String {
        switch storeProduct.productIdentifier {
        case RevenueCatConfig.sixMonthProductIdentifier:
            return AppLanguage.localized("6개월")
        case RevenueCatConfig.weeklyProductIdentifier:
            return AppLanguage.localized("주간")
        default:
            break
        }

        let key: String = switch packageType {
        case .annual: "연간"
        case .sixMonth: "6개월"
        case .threeMonth: "3M"
        case .twoMonth: "2M"
        case .monthly: "월간"
        case .weekly: "주간"
        case .lifetime: "평생 이용"
        default: storeProduct.localizedTitle.isEmpty ? "PRO 이용권" : storeProduct.localizedTitle
        }
        return storeProduct.localizedTitle == key ? key : AppLanguage.localized(key)
    }

    var renewalDescription: String {
        guard packageType != .lifetime else { return AppLanguage.localized("한 번 구매로 계속 이용") }
        guard let weeklyPrice = storeProduct.localizedPricePerWeek else { return AppLanguage.localized("주간 환산 가격 제공") }
        return String.localizedStringWithFormat(AppLanguage.localized("주당 약 %@"), weeklyPrice)
    }

    var pricePeriodLabel: String {
        switch storeProduct.productIdentifier {
        case RevenueCatConfig.sixMonthProductIdentifier:
            return AppLanguage.localized("6개월마다")
        case RevenueCatConfig.weeklyProductIdentifier:
            return AppLanguage.localized("매주")
        default:
            break
        }

        let key: String = switch packageType {
        case .annual: "매년"
        case .sixMonth: "6개월마다"
        case .threeMonth: "3M"
        case .twoMonth: "2M"
        case .monthly: "매월"
        case .weekly: "매주"
        case .lifetime: "1회"
        default: ""
        }
        return AppLanguage.localized(key)
    }
}

#Preview("PRO Paywall") {
    ProPaywallView(onSubscribed: {})
        .environmentObject(SubscriptionStore())
}
