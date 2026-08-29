import SwiftUI
import Observation

struct MainTabView: View {
    @State private var selectedTab = AppTab.home
    @State private var tabBarScrollState = MainTabBarScrollState()

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .history:
                    HistoryView()
                case .agents:
                    AgentsView()
                case .profile:
                    ProfileView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChartTabBar(selection: $selectedTab, isCompact: tabBarScrollState.isCompact)
                .frame(maxWidth: tabBarScrollState.isCompact ? 276 : 356)
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
                .offset(y: 5)
                .animation(.spring(response: 0.36, dampingFraction: 0.92), value: tabBarScrollState.isCompact)
        }
        .environment(tabBarScrollState)
        .onChange(of: selectedTab) { _, _ in
            tabBarScrollState.reset()
        }
    }
}

@MainActor
@Observable
final class MainTabBarScrollState {
    private(set) var isCompact = false
    @ObservationIgnored private var lastScrollOffset: CGFloat?
    @ObservationIgnored private var directionalTravel: CGFloat = 0
    @ObservationIgnored private var lastTransitionTime: TimeInterval = 0

    func update(offset: CGFloat) {
        guard offset.isFinite else { return }
        guard let previous = lastScrollOffset else {
            lastScrollOffset = offset
            return
        }
        lastScrollOffset = offset

        let delta = offset - previous
        guard abs(delta) < 80, abs(delta) > 0.30 else { return }

        if offset >= -2 {
            directionalTravel = 0
            transition(to: false)
            return
        }

        if delta < 0 {
            directionalTravel = max(-64, min(0, directionalTravel) + delta)
            if offset <= -26, directionalTravel <= -18, !isCompact {
                directionalTravel = 0
                transition(to: true)
            }
        } else {
            directionalTravel = min(64, max(0, directionalTravel) + delta)
            if directionalTravel >= 24, isCompact {
                directionalTravel = 0
                transition(to: false)
            }
        }
    }

    private func transition(to compact: Bool) {
        guard compact != isCompact else { return }
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastTransitionTime >= 0.30 else { return }
        lastTransitionTime = now
        isCompact = compact
    }

    func reset() {
        lastScrollOffset = nil
        directionalTravel = 0
        lastTransitionTime = 0
        isCompact = false
    }
}

private struct ChartTabBar: View {
    @Binding var selection: AppTab
    let isCompact: Bool

    var body: some View {
        HStack(spacing: isCompact ? 4 : 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: isCompact ? 18 : 20, weight: .bold))
                        .frame(
                            width: isCompact ? 44 : 58,
                            height: isCompact ? 34 : 40
                        )
                        .background(
                            selection == tab ? ChartTheme.mint : .clear,
                            in: RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                        )
                        .foregroundStyle(selection == tab ? .black : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, isCompact ? 7 : 9)
        .padding(.vertical, isCompact ? 4 : 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 26 : 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isCompact ? 26 : 32, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.26), radius: 18, y: 7)
    }
}

private struct MainScrollOffsetModifier: ViewModifier {
    @Environment(MainTabBarScrollState.self) private var tabBarState

    func body(content: Content) -> some View {
        content
            .background(alignment: .top) {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("main-tab-scroll")).minY
                    Color.clear
                        .onAppear { tabBarState.update(offset: offset) }
                        .onChange(of: offset) { _, newOffset in
                            tabBarState.update(offset: newOffset)
                        }
                }
            }
    }
}

extension View {
    func reportsMainScrollOffset() -> some View {
        modifier(MainScrollOffsetModifier())
    }
}

#Preview("Main") {
    MainTabView()
}
