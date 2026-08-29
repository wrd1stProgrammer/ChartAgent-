import SwiftUI

enum OnboardingPageSequence {
    static let lastContentPage = 11
    static let paywallPage = 12
    static let totalPages = 13

    static func nextPage(after page: Int) -> Int {
        min(page + 1, paywallPage)
    }
}

struct OnboardingFlow: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var transitionDirection: CGFloat = 1
    @State private var profile = OnboardingProfile()
    @State private var hasAcceptedTerms = false
    @AppStorage("profileName") private var storedName = ""
    @AppStorage("profileExperience") private var storedExperience = TradingExperience.intermediate.rawValue
    @AppStorage("profileMarket") private var storedMarket = MarketFocus.crypto.rawValue
    @AppStorage("profileStyle") private var storedStyle = TradingStyle.swing.rawValue
    @AppStorage("profileChallenge") private var storedChallenge = TradingChallenge.entries.rawValue

    var body: some View {
        ZStack {
            if page == OnboardingPageSequence.paywallPage {
                ProPaywallView(
                    onSubscribed: finishOnboarding,
                    onDismiss: finishOnboarding
                )
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
            } else {
                AppBackground()
                VStack(spacing: 0) {
                    OnboardingProgress(current: page, total: OnboardingPageSequence.paywallPage)
                        .padding(.horizontal, ChartTheme.screenPadding)
                        .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        pageContent
                            .padding(.horizontal, ChartTheme.screenPadding)
                            .padding(.top, 42)
                            .padding(.bottom, 116)
                            .frame(maxWidth: 620)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .animation(.spring(response: 0.50, dampingFraction: 0.86), value: page)
                }
                .overlay(alignment: .bottom) {
                    PrimaryButton(title: buttonTitle, isEnabled: canContinue) {
                        advance()
                    }
                    .padding(.horizontal, ChartTheme.screenPadding)
                    .padding(.bottom, 8)
                    .staggeredEntrance(index: 3)
                }
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: page)
    }

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch page {
            case 0:
                HeroOnboarding()
            case 1:
                HowItWorksOnboarding()
            case 2:
                NameOnboarding(name: $profile.name)
            case 3:
                ChoiceOnboarding(eyebrow: "2 of 5", title: "트레이딩 경험은\n어느 정도인가요?", subtitle: "설명의 깊이를 맞출게요.", selection: $profile.experience)
            case 4:
                ChoiceOnboarding(eyebrow: "3 of 5", title: "주로 어떤 시장을\n분석하나요?", subtitle: "첫 화면과 예시를 맞춤 구성해요.", selection: $profile.market)
            case 5:
                ChoiceOnboarding(eyebrow: "4 of 5", title: "어떤 스타일로\n거래하나요?", subtitle: "분석의 시간축을 맞출게요.", selection: $profile.style)
            case 6:
                ChoiceOnboarding(eyebrow: "5 of 5", title: "가장 어려운 지점은\n무엇인가요?", subtitle: "모든 회의에서 이 부분을 먼저 확인해요.", selection: $profile.challenge)
            case 7:
                DifferenceOnboarding()
            case 8:
                GrowthOnboarding()
            case 9:
                TeamTrustOnboarding()
            case 10:
                ReadyOnboarding(profile: profile)
            default:
                ConsentOnboarding(hasAcceptedTerms: $hasAcceptedTerms)
            }
        }
        .id(page)
        .staggeredEntrance()
        .transition(
            .asymmetric(
                insertion: .offset(x: transitionDirection * 54).combined(with: .opacity),
                removal: .offset(x: transitionDirection * -32).combined(with: .opacity)
            )
        )
    }

    private var canContinue: Bool {
        if page == 2 {
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if page == OnboardingPageSequence.lastContentPage {
            return hasAcceptedTerms
        }
        return true
    }

    private var buttonTitle: String {
        switch page {
        case 0: "시작하기"
        case 1: "계속"
        case 7: "다음"
        case 8: "다음"
        case 9: "팀 설정하기"
        case 10, 11: "다음"
        default: "계속"
        }
    }

    private func advance() {
        if page == OnboardingPageSequence.lastContentPage { persistProfile() }
        transitionDirection = 1
        withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
            page = OnboardingPageSequence.nextPage(after: page)
        }
    }

    private func persistProfile() {
        storedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        storedExperience = profile.experience.rawValue
        storedMarket = profile.market.rawValue
        storedStyle = profile.style.rawValue
        storedChallenge = profile.challenge.rawValue
    }

    private func finishOnboarding() {
        persistProfile()
        AttributionService.shared.track(.onboardingCompleted)
        onComplete()
    }
}

private struct ConsentOnboarding: View {
    @Binding var hasAcceptedTerms: Bool
    @State private var presentedLegalDocument: LegalDocumentKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("필수 안내")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(ChartTheme.mint)

            Text("분석과 구독 제공에 필요한 정보가 처리됩니다.")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            disclosureRow(
                icon: "checkmark.shield.fill",
                text: "AI 분석 결과는 교육 및 참고용이며 투자 권유가 아닙니다."
            )

            VStack(spacing: 0) {
                legalButton(title: "개인정보 처리 안내", icon: "hand.raised.fill", kind: .privacyPolicy)
                Divider().overlay(.white.opacity(0.10)).padding(.leading, 50)
                legalButton(title: "이용약관", icon: "doc.text.fill", kind: .termsOfUse)
            }
            .background(ChartTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ChartTheme.stroke, lineWidth: 1)
            }

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    hasAcceptedTerms.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: hasAcceptedTerms ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(hasAcceptedTerms ? ChartTheme.mint : .white.opacity(0.42))

                    Text("\(AppLanguage.localized("개인정보 처리 안내")) · \(AppLanguage.localized("이용약관"))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))

                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(ChartTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("확인")
        }
        .sheet(item: $presentedLegalDocument) { kind in
            LegalDocumentSheet(kind: kind)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChartTheme.background)
        }
    }

    private func disclosureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ChartTheme.mint)
                .frame(width: 28)
            Text(AppLanguage.localized(text))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legalButton(title: String, icon: String, kind: LegalDocumentKind) -> some View {
        Button {
            presentedLegalDocument = kind
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(ChartTheme.mint)
                    .frame(width: 28)
                Text(AppLanguage.localized(title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.32))
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Onboarding") {
    OnboardingFlow(onComplete: {})
        .environmentObject(SubscriptionStore())
}
