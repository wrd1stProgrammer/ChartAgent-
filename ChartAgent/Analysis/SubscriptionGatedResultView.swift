import SwiftUI

enum AnalysisResultAccess: Equatable {
    case checking
    case locked
    case unlocked
}

enum AnalysisStartAccess: Equatable {
    case checking
    case available
    case locked
}

enum FreeAnalysisAccess {
    static let storageKey = "chartagent.hasUsedFreeAnalysis"

    static func hasBeenUsed(
        storedValue: Bool,
        hasExistingAnalysis: Bool
    ) -> Bool {
        storedValue || hasExistingAnalysis
    }
}

enum AnalysisStartAccessPolicy {
    static func access(
        isEntitlementResolved: Bool,
        hasProAccess: Bool,
        hasUsedFreeAnalysis: Bool
    ) -> AnalysisStartAccess {
        guard isEntitlementResolved else { return .checking }
        return hasProAccess || !hasUsedFreeAnalysis ? .available : .locked
    }
}

enum AnalysisResultAccessPolicy {
    static func access(
        isEntitlementResolved: Bool,
        isProActive: Bool
    ) -> AnalysisResultAccess {
        guard isEntitlementResolved else { return .checking }
        return isProActive ? .unlocked : .locked
    }
}

struct SubscriptionGatedResultView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var isPaywallPresented = false

    let record: AnalysisRecord
    let imageData: Data?
    let onClose: () -> Void

    private var access: AnalysisResultAccess {
        AnalysisResultAccessPolicy.access(
            isEntitlementResolved: subscriptionStore.isEntitlementResolved,
            isProActive: subscriptionStore.isProActive
        )
    }

    var body: some View {
        ZStack {
            switch access {
            case .unlocked:
                AnalysisResultView(record: record, imageData: imageData, onClose: onClose)
                    .transition(.opacity)
            case .checking:
                obscuredResult
                entitlementLoadingCard
            case .locked:
                lockedResult
            }

            if isPaywallPresented && access == .locked {
                ProPaywallView(
                    backdrop: .branded,
                    onSubscribed: { isPaywallPresented = false },
                    onDismiss: onClose
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: access)
        .animation(.easeInOut(duration: 0.24), value: isPaywallPresented)
    }

    private var obscuredResult: some View {
        AnalysisResultView(record: record, imageData: imageData, isContentLocked: true, onClose: onClose)
            .blur(radius: 11)
            .overlay(Color.black.opacity(0.22))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lockedResult: some View {
        AnalysisResultView(
            record: record,
            imageData: imageData,
            isContentLocked: true,
            onClose: onClose
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            lockedResultFooter
        }
    }

    private var lockedResultFooter: some View {
        VStack(spacing: 10) {
            Label("전체 결론·가격 조건·에이전트 근거는 PRO에서 열립니다.", systemImage: "lock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.66))

            Button {
                isPaywallPresented = true
            } label: {
                HStack(spacing: 8) {
                    Text("PRO로 전체 결과 보기")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(ChartTheme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ChartTheme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ChartTheme.stroke)
                .frame(height: 1)
        }
    }

    private var entitlementLoadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(ChartTheme.mint)
            Text("구독 상태 확인 중")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ChartTheme.stroke, lineWidth: 1)
        }
    }
}
