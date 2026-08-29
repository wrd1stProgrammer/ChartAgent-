import SwiftUI

struct AgentsView: View {
    @EnvironmentObject private var profileStore: AgentProfileStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var editingRoleID: String?

    private var hasAgentCustomizationAccess: Bool {
        subscriptionStore.isEntitlementResolved
            && subscriptionStore.isProActive
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                roster
            }
            .padding(.horizontal, ChartTheme.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 34)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .reportsMainScrollOffset()
        }
        .coordinateSpace(.named("main-tab-scroll"))
        .sheet(item: editingProfile) { profile in
            AgentProfileEditor(profile: profile)
                .environmentObject(profileStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChartTheme.background)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AppLanguage.localized("에이전트 스튜디오"))
                    .font(.system(size: 28, weight: .black))
                Text(AppLanguage.localized("이름·말투·판단 관점만 직접 설계하세요"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("5")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(ChartTheme.mint)
                Text(AppLanguage.localized("PROFILES"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(ChartTheme.secondaryText)
            }
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(AppLanguage.localized("내 분석팀"), systemImage: "person.3.sequence.fill")
                    .font(.headline.bold())
                Spacer()
                Text(AppLanguage.localized("5 ROLES · FIXED"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(ChartTheme.secondaryText)
            }

            ForEach(profileStore.agents) { agent in
                Button {
                    guard hasAgentCustomizationAccess else { return }
                    editingRoleID = agent.id
                } label: {
                    HStack(spacing: 13) {
                        PixelAgentView(
                            agent: agent,
                            direction: .front,
                            pose: .idle,
                            phase: 0,
                            scale: 0.82,
                            scaleAnchor: .center
                        )
                            .frame(width: 64, height: 64)
                            .background(agent.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) {
                                Text(agent.localizedName).font(.headline.bold())
                                Text(agent.localizedRole)
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(agent.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(agent.accent.opacity(0.10), in: Capsule())
                            }
                            Text(profileStore.profile(for: agent.id)?.localizedTone ?? "")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ChartTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: hasAgentCustomizationAccess ? "slider.horizontal.3" : "lock.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(hasAgentCustomizationAccess ? agent.accent : ChartTheme.secondaryText)
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!hasAgentCustomizationAccess)
                .accessibilityHint(
                    hasAgentCustomizationAccess
                        ? ""
                        : AppLanguage.localized("PRO 플랜 보기")
                )
                .chartCard(
                    fill: ChartTheme.surface,
                    stroke: ChartTheme.stroke,
                    radius: 17
                )
            }
        }
    }

    private var editingProfile: Binding<AgentProfile?> {
        Binding(
            get: { editingRoleID.flatMap(profileStore.profile) },
            set: { if $0 == nil { editingRoleID = nil } }
        )
    }
}

private struct AgentProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: AgentProfileStore
    let original: AgentProfile
    @State private var name: String
    @State private var tone: String
    @State private var concept: InvestmentConcept
    @State private var validationMessage: String?

    init(profile: AgentProfile) {
        original = profile
        _name = State(initialValue: profile.localizedDisplayName)
        _tone = State(initialValue: profile.localizedTone)
        _concept = State(initialValue: profile.concept)
    }

    private var previewAgent: PixelAgent {
        let base = PixelAgent.defaultTeam.first { $0.id == original.roleID }!
        guard let draft = try? AgentProfile(
            roleID: original.roleID,
            displayName: name.isEmpty ? original.displayName : name,
            tone: tone.isEmpty ? original.tone : tone,
            concept: concept,
            appearanceID: original.appearanceID
        ) else { return base.applying(original) }
        return base.applying(draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    textFieldSection
                    conceptSection
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(ChartTheme.coral)
                    }
                }
                .padding(ChartTheme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(ChartTheme.background.ignoresSafeArea())
            .navigationTitle(AppLanguage.localized("에이전트 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLanguage.localized("초기화")) {
                        profileStore.reset(roleID: original.roleID)
                        dismiss()
                    }
                    .foregroundStyle(ChartTheme.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLanguage.localized("저장"), action: save)
                        .fontWeight(.bold)
                        .foregroundStyle(ChartTheme.mint)
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            PixelAgentView(agent: previewAgent, direction: .front, pose: .talking, phase: 0, scale: 1.34, showsName: true)
                .frame(width: 116, height: 142)
            Text(concept.localizedTitle)
                .font(.subheadline.bold())
                .foregroundStyle(previewAgent.accent)
            Text(concept.localizedSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChartTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .chartCard(fill: previewAgent.accent.opacity(0.07), stroke: previewAgent.accent.opacity(0.32), radius: 22)
    }

    private var textFieldSection: some View {
        VStack(spacing: 14) {
            boundedField(title: "에이전트 이름", value: $name, limit: 10, placeholder: "10자 이내")
            boundedField(title: "말투", value: $tone, limit: 20, placeholder: "예: 짧고 단호하게")
        }
    }

    private func boundedField(title: String, value: Binding<String>, limit: Int, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppLanguage.localized(title)).font(.subheadline.bold())
                Spacer()
                Text("\(value.wrappedValue.count)/\(limit)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(value.wrappedValue.count <= limit ? ChartTheme.secondaryText : ChartTheme.coral)
            }
            TextField(AppLanguage.localized(placeholder), text: value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: value.wrappedValue) {
                    let cleaned = value.wrappedValue.filter { !$0.isNewline }
                    value.wrappedValue = String(cleaned.prefix(limit))
                }
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(AppLanguage.localized("투자 판단 컨셉"), systemImage: "scope")
                .font(.headline.bold())
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 9) {
                ForEach(InvestmentConcept.allCases) { item in
                    let isUnavailable = !profileStore.isConceptAvailable(item, excluding: original.roleID)
                    Button {
                        concept = item
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: concept == item ? "checkmark.circle.fill" : isUnavailable ? "lock.fill" : "circle")
                            Text(item.localizedTitle)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(concept == item ? .black : .white.opacity(isUnavailable ? 0.30 : 0.72))
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(concept == item ? ChartTheme.mint : ChartTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isUnavailable)
                    .accessibilityHint(isUnavailable ? AppLanguage.localized("다른 에이전트가 사용 중입니다.") : "")
                }
            }
        }
    }

    private func save() {
        do {
            let profile = try AgentProfile(
                roleID: original.roleID,
                displayName: original.storageDisplayName(from: name),
                tone: original.storageTone(from: tone),
                concept: concept,
                appearanceID: original.appearanceID
            )
            try profileStore.saveUnique(profile)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
