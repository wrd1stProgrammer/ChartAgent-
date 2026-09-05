import SwiftUI
import UIKit

struct ChartAnnotationViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let annotations: [ChartAnnotation]
    let summary: String
    @State private var selectedID: String?
    @State private var showsAnnotations = true
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private var selected: ChartAnnotation? { annotations.first { $0.id == selectedID } ?? annotations.first }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.accessibilityLabel("차트 닫기")
                Spacer()
                Text("차트 자세히 보기").font(.subheadline.bold())
                Spacer()
                Button { showsAnnotations.toggle() } label: {
                    Image(systemName: showsAnnotations ? "eye" : "pencil.tip").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(LocalizedStringKey(showsAnnotations ? "원본 보기" : "작도 보기")))
            }
            .foregroundStyle(.white)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            GeometryReader { geometry in
                AnnotatedChartCanvas(image: image, annotations: showsAnnotations ? annotations : [],
                                     selectedID: $selectedID, expanded: true)
                    .scaleEffect(min(max(scale * magnification, 1), 4))
                    .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                    .gesture(MagnifyGesture()
                        .updating($magnification) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            scale = min(max(scale * value.magnification, 1), 4)
                            offset = bounded(offset, container: geometry.size)
                        })
                    .simultaneousGesture(DragGesture()
                        .updating($drag) { value, state, _ in
                            if scale > 1 { state = value.translation }
                        }
                        .onEnded { value in
                            guard scale > 1 else { return }
                            offset = bounded(CGSize(width: offset.width + value.translation.width,
                                                    height: offset.height + value.translation.height), container: geometry.size)
                        })
            }
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LocalizedStringKey(showsAnnotations ? "핵심 작도" : "원본 차트")).font(.subheadline.bold())
                    Spacer()
                    Button {
                        scale = scale > 1 ? 1 : 2
                        offset = .zero
                    } label: {
                        Label(LocalizedStringKey(scale > 1 ? "크기 초기화" : "2배 확대"), systemImage: scale > 1 ? "arrow.counterclockwise" : "plus.magnifyingglass")
                            .font(.caption.bold()).foregroundStyle(ChartTheme.mint).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chart.annotations.zoom")
                }
                if showsAnnotations, let selected {
                    Text(selected.title).font(.headline).foregroundStyle(ChartAnnotationStyle.color(selected.tone))
                    Text(selected.detail).font(.subheadline).foregroundStyle(.white.opacity(0.84))
                    Text(selected.outlook).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(showsAnnotations ? summary : AppLanguage.localized("업로드한 원본 차트입니다."))
                        .font(.subheadline).foregroundStyle(ChartTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 20)
            .background(ChartTheme.surface)
        }
        .background(ChartTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { selectedID = annotations.first?.id }
    }

    private func bounded(_ proposed: CGSize, container: CGSize) -> CGSize {
        let x = container.width * (scale - 1) / 2
        let y = container.height * (scale - 1) / 2
        return CGSize(width: min(max(proposed.width, -x), x), height: min(max(proposed.height, -y), y))
    }
}
