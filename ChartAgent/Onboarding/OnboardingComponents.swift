import BorderBeamKit
import SwiftUI

enum OnboardingCTAVisualPolicy {
    static let usesHighContrastBeam = true
}

struct OnboardingHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLanguage.localized(eyebrow).uppercased())
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(ChartTheme.mint)
            Text(AppLanguage.localized(title))
                .font(.system(size: 31, weight: .black))
                .tracking(-1.0)
                .foregroundStyle(.white)
            Text(AppLanguage.localized(subtitle))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ChartTheme.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? ChartTheme.mint : Color.white.opacity(0.12))
                    .frame(height: 5)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: current)
        .accessibilityLabel(
            String.localizedStringWithFormat(
                AppLanguage.localized("온보딩 %@ / %@"),
                String(current + 1),
                String(total)
            )
        )
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(AppLanguage.localized(title))
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(ChartTheme.mint.opacity(isEnabled ? 1 : 0.22), in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: ChartTheme.mint.opacity(isEnabled ? 0.24 : 0), radius: 24, y: 8)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(reduceMotion && isEnabled ? 0.72 : 0.10), lineWidth: reduceMotion ? 2 : 1)
        }
        .onboardingBeam(active: isEnabled && !reduceMotion, cornerRadius: 20)
    }
}

struct ChoiceOnboarding<Value: TradingChoice>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
            VStack(spacing: 11) {
                ForEach(Array(Value.allCases.enumerated()), id: \.element.id) { index, choice in
                    Button {
                        selection = choice
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: choice.icon)
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(selection == choice ? .black : ChartTheme.mint)
                                .frame(width: 48, height: 48)
                                .background(selection == choice ? ChartTheme.mint : ChartTheme.mintDeep, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(choice.subtitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ChartTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if selection == choice {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(ChartTheme.mint)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .chartCard(
                            fill: ChartTheme.surface,
                            stroke: selection == choice ? ChartTheme.mint : ChartTheme.stroke
                        )
                    }
                    .buttonStyle(.plain)
                    .staggeredEntrance(index: index + 1)
                }
            }
        }
    }
}

private struct StaggeredEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 16)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.985)
            .onAppear {
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.18)
                        : .spring(response: 0.48, dampingFraction: 0.86)
                            .delay(Double(index) * 0.055)
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredEntrance(index: Int = 0) -> some View {
        modifier(StaggeredEntrance(index: index))
    }

    func onboardingBeam(active: Bool = true, cornerRadius: CGFloat = 20) -> some View {
        borderBeam(
            .line,
            colorVariant: OnboardingCTAVisualPolicy.usesHighContrastBeam ? .colorful : .ocean,
            theme: .dark,
            duration: 3.2,
            active: active,
            borderRadius: cornerRadius,
            brightness: 1.48,
            saturation: 1.0,
            strength: 1.0,
            tuning: BeamTuning(
                strokeOpacity: 3.2,
                innerOpacity: 1.8,
                bloomOpacity: 2.4,
                glowBrightness: 1.9,
                glowSaturate: 1.35
            )
        )
    }
}

struct FeatureRow: View {
    let number: String
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(ChartTheme.mint)
                .frame(width: 54, height: 54)
                .background(ChartTheme.mintDeep, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(number)
                    Text(AppLanguage.localized(title))
                }
                .font(.system(size: 18, weight: .bold))
                Text(AppLanguage.localized(subtitle))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ChartTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .chartCard()
    }
}
