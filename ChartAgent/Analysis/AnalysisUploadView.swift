import PhotosUI
import SwiftUI
import UIKit

struct AnalysisUploadView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var analysisStore: AnalysisStore
    @EnvironmentObject private var agentProfileStore: AgentProfileStore
    @EnvironmentObject private var runCoordinator: AnalysisRunCoordinator
    @AppStorage(FreeAnalysisAccess.storageKey) private var hasUsedFreeAnalysis = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var sourceImage: UIImage?
    @State private var cropDraft: ChartImageCropDraft?
    @State private var includesNews = false
    @State private var inputError: ChartAgentAPIError?
    @State private var draft: AnalysisDraft?
    @State private var imageViewer: ChartImageViewerDestination?
    @State private var isImageSourceSheetPresented = false
    @State private var pendingImageSource: ImageSourceChoice?
    @State private var isPhotoLibraryPresented = false
    @State private var isCameraPresented = false

    var body: some View {
        ZStack {
            ChartTheme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    chartPreview
                    newsOption
                    if let inputError { errorPanel(inputError) }
                    captureTip
                    if subscriptionStore.isEntitlementResolved
                        && !subscriptionStore.isProActive {
                        resultAccessNotice
                    }
                    PrimaryButton(title: buttonTitle) { beginAnalysis() }
                        .disabled(!canStart)
                        .opacity(canStart ? 1 : 0.42)
                }
                .padding(ChartTheme.screenPadding)
                .padding(.bottom, 16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $isImageSourceSheetPresented, onDismiss: presentPendingImageSource) {
            ImageSourceChoiceSheet(
                showsCamera: UIImagePickerController.isSourceTypeAvailable(.camera)
            ) { source in
                pendingImageSource = source
                isImageSourceSheetPresented = false
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .presentationBackground(ChartTheme.surfaceRaised)
            .presentationCornerRadius(26)
        }
        .photosPicker(
            isPresented: $isPhotoLibraryPresented,
            selection: $selectedItem,
            matching: .images
        )
        .task(id: selectedItem) { await loadSelectedImage() }
        .fullScreenCover(item: $cropDraft) { draft in
            ChartImageCropView(image: draft.image) { croppedData in
                sourceImage = draft.image
                selectedImageData = croppedData
                inputError = nil
            }
        }
        .fullScreenCover(item: $draft) { draft in
            AnalysisSessionView(draft: draft, runCoordinator: runCoordinator) {
                runCoordinator.reset()
                self.draft = nil
                clearSelectedImage()
            }
        }
        .fullScreenCover(item: $imageViewer) { destination in
            ChartImageViewer(image: destination.image)
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            ChartCameraPicker(isPresented: $isCameraPresented) { image in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    cropDraft = ChartImageCropDraft(image: image)
                    inputError = nil
                }
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: restoreActiveAnalysisIfNeeded)
    }

    private var newsOption: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(includesNews ? .black : ChartTheme.mint)
                .frame(width: 42, height: 42)
                .background(includesNews ? ChartTheme.mint : ChartTheme.mintDeep, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("뉴스 반영").font(.headline.bold())
                Text("이미지에서 판독한 심볼의 최신 뉴스를 보조 근거로 사용합니다.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChartTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Toggle("뉴스 반영", isOn: $includesNews).labelsHidden().tint(ChartTheme.mint)
        }
        .padding(16)
        .chartCard(fill: includesNews ? ChartTheme.mintDeep.opacity(0.62) : ChartTheme.surfaceRaised, radius: 18)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: includesNews)
    }

    private var captureTip: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("판독 정확도를 높이려면", systemImage: "viewfinder")
                .font(.headline)
                .foregroundStyle(ChartTheme.mint)
            Text("캔들, 종목명, 시간대, 가격 축이 함께 보이도록 캡처해 주세요. 심볼이나 시간대를 판독할 수 없으면 분석을 안전하게 중단합니다.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ChartTheme.secondaryText)
                .lineSpacing(4)
        }
        .padding(18)
        .chartCard(fill: ChartTheme.mintDeep.opacity(0.40), stroke: ChartTheme.mint.opacity(0.24))
    }

    private var resultAccessNotice: some View {
        Label {
            Text("분석은 진행되며 전체 결과 확인에는 PRO 구독이 필요합니다.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.fill")
                .foregroundStyle(ChartTheme.mint)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(ChartTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var chartPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(Color.black)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        imageViewer = ChartImageViewerDestination(image: image)
                    }

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.76), in: Circle())
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)

                Button {
                    guard let sourceImage else { return }
                    cropDraft = ChartImageCropDraft(image: sourceImage)
                } label: {
                    Label("크기 조절", systemImage: "crop")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(.black.opacity(0.76), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(12)
            } else {
                Button {
                    isImageSourceSheetPresented = true
                } label: {
                    VStack(spacing: 13) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(ChartTheme.mint)
                        Text("분석할 차트 캡처를 선택하세요")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("이미지는 분석 후 기기 기록에만 저장됩니다.")
                            .font(.caption)
                            .foregroundStyle(ChartTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(ChartTheme.surface)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("사진 보관함 또는 카메라에서 차트 이미지를 선택합니다")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(ChartTheme.stroke) }
    }

    private func errorPanel(_ error: ChartAgentAPIError) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ChartTheme.coral)
            VStack(alignment: .leading, spacing: 5) {
                Text(error.localizedDescription).font(.subheadline.bold())
                if let recovery = error.recoverySuggestion {
                    Text(recovery).font(.caption).foregroundStyle(ChartTheme.secondaryText)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chartCard(fill: ChartTheme.coral.opacity(0.08), stroke: ChartTheme.coral.opacity(0.34), radius: 16)
    }

    private var analysisStartAccess: AnalysisStartAccess {
        AnalysisStartAccessPolicy.access(
            isEntitlementResolved: subscriptionStore.isEntitlementResolved,
            hasProAccess: subscriptionStore.isProActive,
            hasUsedFreeAnalysis: FreeAnalysisAccess.hasBeenUsed(
                storedValue: hasUsedFreeAnalysis,
                hasExistingAnalysis: !analysisStore.records.isEmpty
            )
        )
    }

    private var canStart: Bool {
        selectedImageData != nil && analysisStartAccess == .available
    }

    private var buttonTitle: String {
        if analysisStartAccess == .locked { return AppLanguage.localized("PRO 플랜 보기") }
        if analysisStartAccess == .checking { return AppLanguage.localized("구독 상태 확인 중") }
        guard includesNews else { return AppLanguage.localized("차트 분석 시작") }
        return AppLanguage.localized("뉴스 포함 분석")
    }

    private func beginAnalysis() {
        guard analysisStartAccess == .available, let selectedImageData else { return }
        AttributionService.shared.track(
            .analysisStarted,
            properties: [
                "includes_news": includesNews,
                "agent_count": activeAgentIDs.count
            ]
        )
        let newDraft = AnalysisDraft(
            imageData: selectedImageData,
            includesNews: includesNews,
            activeAgentIDs: activeAgentIDs,
            agentProfiles: agentProfileStore.profiles.filter { activeAgentIDs.contains($0.roleID) }
        )
        runCoordinator.prepare(newDraft)
        draft = newDraft
        inputError = nil
    }

    private func clearSelectedImage() {
        selectedItem = nil
        selectedImageData = nil
        sourceImage = nil
        cropDraft = nil
        inputError = nil
    }

    private func restoreActiveAnalysisIfNeeded() {
        guard draft == nil, let activeDraft = runCoordinator.activeDraft else { return }
        selectedImageData = activeDraft.imageData
        sourceImage = UIImage(data: activeDraft.imageData)
        includesNews = activeDraft.includesNews
        draft = activeDraft
    }

    private func presentPendingImageSource() {
        guard let source = pendingImageSource else { return }
        pendingImageSource = nil
        switch source {
        case .photoLibrary:
            isPhotoLibraryPresented = true
        case .camera:
            isCameraPresented = true
        }
    }

    private var activeAgentIDs: [String] {
        PixelAgent.defaultTeam.map(\.id)
    }

    private func loadSelectedImage() async {
        guard let selectedItem else { return }
        do {
            guard let raw = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw) else {
                throw ChartAgentAPIError.server(
                    APIErrorPayload(
                        code: "image_decode_failed",
                        message: AppLanguage.localized("이미지 파일을 읽을 수 없습니다."),
                        recovery: AppLanguage.localized("다른 차트 이미지로 다시 시도해 주세요.")
                    )
                )
            }
            cropDraft = ChartImageCropDraft(image: image)
            inputError = nil
        } catch let error as ChartAgentAPIError {
            selectedImageData = nil
            sourceImage = nil
            inputError = error
        } catch {
            selectedImageData = nil
            sourceImage = nil
            inputError = .transport(error.localizedDescription)
        }
    }

}

private enum ImageSourceChoice {
    case photoLibrary
    case camera
}

private struct ImageSourceChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let showsCamera: Bool
    let onSelect: (ImageSourceChoice) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(AppLanguage.localized("차트 이미지 선택"))
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            sourceButton(
                title: AppLanguage.localized("사진 보관함"),
                systemImage: "photo.on.rectangle"
            ) {
                onSelect(.photoLibrary)
            }

            if showsCamera {
                sourceButton(
                    title: AppLanguage.localized("카메라"),
                    systemImage: "camera.fill"
                ) {
                    onSelect(.camera)
                }
            }

            Button(AppLanguage.localized("취소"), role: .cancel) {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ChartTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private func sourceButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .padding(.horizontal, 16)
                .background(ChartTheme.surface, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

private struct ChartCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ChartCameraPicker

        init(parent: ChartCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

extension UIImage {
    func chartAgentJPEGData(maxDimension: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let normalized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return normalized.jpegData(compressionQuality: 0.86)
    }
}
