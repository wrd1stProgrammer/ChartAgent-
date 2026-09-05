import SwiftUI
import UIKit

struct ChartAnnotationCard: View {
    @EnvironmentObject private var analysisStore: AnalysisStore
    let analysisID: String
    let imageData: Data
    let analysis: AnalysisPayload
    let onScenarioSelected: (Int) -> Void
    var isLocked = false

    @State private var document: ChartAnnotationDocument?
    @State private var selectedID: String?
    @State private var showsAnnotations = true
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var failed = false
    @State private var retry = 0

    private var cacheKey: String {
        ChartAnnotationDocument.cacheKey(analysisID: analysisID, locale: AppLanguage.current.responseLanguage)
    }
    private var annotations: [ChartAnnotation] { isLocked ? [] : document?.annotations ?? [] }
    private var selected: ChartAnnotation? { annotations.first { $0.id == selectedID } ?? annotations.first }

    var body: some View {
        if let image = UIImage(data: imageData) {
            VStack(spacing: 0) {
                header
                AnnotatedChartCanvas(image: image, annotations: showsAnnotations ? annotations : [], selectedID: $selectedID)
                    .aspectRatio(max(image.size.width / image.size.height, 1), contentMode: .fit)
                    .background(ChartTheme.background)
                footer
            }
            .clipShape(RoundedRectangle(cornerRadius: ChartTheme.corner))
            .chartCard()
            .padding(.top, 10)
            .task(id: cacheKey + ":\(retry):\(isLocked)") { await loadAnnotations() }
            .fullScreenCover(isPresented: $isExpanded) {
                ChartAnnotationViewer(image: image, annotations: annotations, summary: document?.summary ?? "")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.outline").foregroundStyle(ChartTheme.mint)
            Text("핵심 작도").font(.subheadline.bold())
            Spacer(minLength: 4)
            if !annotations.isEmpty {
                Button { showsAnnotations.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showsAnnotations ? "eye" : "pencil.tip")
                        Text(LocalizedStringKey(showsAnnotations ? "원본 보기" : "작도 보기"))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChartTheme.mint)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chart.annotations.toggle")
            }
            Button { isExpanded = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("차트 확대")
        }
        .frame(minHeight: 50)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .background(ChartTheme.surface)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLocked {
                Label("차트 작도는 PRO에서 열립니다.", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(ChartTheme.secondaryText)
            } else if isLoading {
                HStack(spacing: 9) {
                    ProgressView().tint(ChartTheme.mint)
                    Text("차트 위에 핵심 근거를 표시하고 있어요")
                        .font(.caption).foregroundStyle(ChartTheme.secondaryText)
                }
            } else if failed {
                HStack(spacing: 8) {
                    Text("작도를 불러오지 못했어요")
                        .font(.caption).foregroundStyle(ChartTheme.secondaryText)
                    Spacer(minLength: 0)
                    Button("다시 시도") { retry += 1 }
                        .font(.caption.bold()).foregroundStyle(ChartTheme.mint)
                        .frame(minHeight: 44)
                }
            } else if !showsAnnotations {
                Text("업로드한 원본 차트입니다.")
                    .font(.caption).foregroundStyle(ChartTheme.secondaryText)
            } else if let selected {
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(ChartAnnotationStyle.color(selected.tone)).frame(width: 6, height: 6).padding(.top, 5)
                    Text(selected.detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(selected.outlook)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                if let index = selected.scenarioIndex, analysis.scenarios.indices.contains(index) {
                    Button { onScenarioSelected(index) } label: {
                        Label("조건별 시나리오", systemImage: "arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ChartTheme.mint)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chart.annotations.scenario")
                }
                if annotations.count > 1 {
                    Text("차트의 번호를 누르면 근거를 볼 수 있어요")
                        .font(.system(size: 11)).foregroundStyle(ChartTheme.secondaryText)
                }
            } else {
                Text(document?.summary ?? AppLanguage.localized("확실히 보이는 근거만 표시합니다."))
                    .font(.caption).foregroundStyle(ChartTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ChartTheme.surface)
    }

    @MainActor
    private func loadAnnotations() async {
        guard !isLocked else { document = nil; return }
        let locale = AppLanguage.current.responseLanguage
        let requestKey = ChartAnnotationDocument.cacheKey(analysisID: analysisID, locale: locale)
        document = nil
        if let cached = analysisStore.chartAnnotations[requestKey], cached.locale == locale,
           cached.hasValidScenarioLinks(count: analysis.scenarios.count) {
            document = cached
            selectedID = cached.annotations.first?.id
            return
        }
        isLoading = true
        failed = false
        defer { isLoading = false }
        do {
            let received = try await analysisStore.prepareChartAnnotations(
                analysisID: analysisID, imageData: imageData, analysis: analysis, locale: locale, retry: retry > 0
            ).value
            try Task.checkCancellation()
            document = received
            selectedID = received.annotations.first?.id
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
