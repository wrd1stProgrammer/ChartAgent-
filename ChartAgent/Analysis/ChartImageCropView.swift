import SwiftUI
import UIKit

struct ChartImageCropDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ChartImageCropView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let onApply: (Data) -> Void

    @State private var selection = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var gestureStartSelection: CGRect?
    @State private var cropError = false

    private let cropBlue = Color(red: 0.35, green: 0.58, blue: 1)
    private let photoPickerTopClearance: CGFloat = 44

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            cropStage
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                header
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
            .padding(.top, photoPickerTopClearance)
            .background(Color.black)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 8)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button("취소") { dismiss() }
                .foregroundStyle(Color.white.opacity(0.62))
                .frame(width: 72, height: 54, alignment: .leading)
                .accessibilityLabel("이미지 크롭 취소")

            Spacer(minLength: 8)

            Text("이미지 크롭")
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("확인") { applyCrop() }
                .fontWeight(.semibold)
                .foregroundStyle(cropBlue)
                .frame(width: 72, height: 54, alignment: .trailing)
                .accessibilityLabel("선택한 영역 사용")
        }
        .font(.system(size: 17))
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private var cropStage: some View {
        GeometryReader { proxy in
            let imageRect = displayedImageRect(in: proxy.size)
            let cropRect = displayedCropRect(in: imageRect)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                dimmedOutside(cropRect: cropRect, canvasSize: proxy.size)
                    .allowsHitTesting(false)

                cropSelection(cropRect: cropRect, imageRect: imageRect)

                if cropError {
                    Text("선택 영역을 만들 수 없습니다.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.red.opacity(0.82), in: Capsule())
                        .position(x: proxy.size.width / 2, y: max(24, imageRect.minY - 28))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func dimmedOutside(cropRect: CGRect, canvasSize: CGSize) -> some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRect(cropRect)
            context.fill(
                path,
                with: .color(.black.opacity(0.62)),
                style: FillStyle(eoFill: true)
            )
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func cropSelection(cropRect: CGRect, imageRect: CGRect) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(moveGesture(in: imageRect))
                .accessibilityLabel("선택 영역")
                .accessibilityHint("드래그하여 선택 영역을 이동합니다")

            Rectangle()
                .stroke(cropBlue, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)

            Rectangle()
                .stroke(.white.opacity(0.86), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .frame(width: max(0, cropRect.width - 4), height: max(0, cropRect.height - 4))
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)

            ForEach(CropHandle.allCases) { handle in
                cropHandle(handle, cropRect: cropRect, imageRect: imageRect)
            }
        }
    }

    private func cropHandle(_ handle: CropHandle, cropRect: CGRect, imageRect: CGRect) -> some View {
        Circle()
            .fill(.white)
            .overlay { Circle().stroke(cropBlue, lineWidth: 2) }
            .frame(width: 24, height: 24)
            .contentShape(Circle().inset(by: -12))
            .position(handle.position(in: cropRect))
            .gesture(resizeGesture(handle: handle, in: imageRect))
            .accessibilityLabel(handle.accessibilityLabel)
            .accessibilityHint("드래그하여 자를 영역의 크기를 조절합니다")
    }

    private func displayedImageRect(in available: CGSize) -> CGRect {
        let padding: CGFloat = 18
        let bounds = CGSize(
            width: max(1, available.width - padding * 2),
            height: max(1, available.height - padding * 2)
        )
        guard image.size.width > 0, image.size.height > 0 else {
            return CGRect(x: padding, y: padding, width: bounds.width, height: bounds.height)
        }
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (available.width - fitted.width) / 2,
            y: (available.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func displayedCropRect(in imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + selection.minX * imageRect.width,
            y: imageRect.minY + selection.minY * imageRect.height,
            width: selection.width * imageRect.width,
            height: selection.height * imageRect.height
        )
    }

    private func moveGesture(in imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = beginGestureIfNeeded()
                let deltaX = value.translation.width / max(1, imageRect.width)
                let deltaY = value.translation.height / max(1, imageRect.height)
                selection.origin.x = clamped(start.minX + deltaX, lower: 0, upper: 1 - start.width)
                selection.origin.y = clamped(start.minY + deltaY, lower: 0, upper: 1 - start.height)
                cropError = false
            }
            .onEnded { _ in gestureStartSelection = nil }
    }

    private func resizeGesture(handle: CropHandle, in imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = beginGestureIfNeeded()
                let deltaX = value.translation.width / max(1, imageRect.width)
                let deltaY = value.translation.height / max(1, imageRect.height)
                let minimumWidth = min(0.32, max(0.08, 72 / max(1, imageRect.width)))
                let minimumHeight = min(0.32, max(0.08, 72 / max(1, imageRect.height)))

                var minX = start.minX
                var minY = start.minY
                var maxX = start.maxX
                var maxY = start.maxY

                if handle.movesLeft {
                    minX = clamped(start.minX + deltaX, lower: 0, upper: start.maxX - minimumWidth)
                } else {
                    maxX = clamped(start.maxX + deltaX, lower: start.minX + minimumWidth, upper: 1)
                }

                if handle.movesTop {
                    minY = clamped(start.minY + deltaY, lower: 0, upper: start.maxY - minimumHeight)
                } else {
                    maxY = clamped(start.maxY + deltaY, lower: start.minY + minimumHeight, upper: 1)
                }

                selection = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                cropError = false
            }
            .onEnded { _ in gestureStartSelection = nil }
    }

    private func beginGestureIfNeeded() -> CGRect {
        if let gestureStartSelection { return gestureStartSelection }
        gestureStartSelection = selection
        return selection
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func applyCrop() {
        guard let jpeg = croppedJPEG() else {
            cropError = true
            return
        }
        onApply(jpeg)
        dismiss()
    }

    private func croppedJPEG() -> Data? {
        guard let normalized = image.chartAgentNormalizedImage(),
              let source = normalized.cgImage else { return nil }

        let imageSize = normalized.size
        var cropRect = CGRect(
            x: selection.minX * imageSize.width,
            y: selection.minY * imageSize.height,
            width: selection.width * imageSize.width,
            height: selection.height * imageSize.height
        ).integral
        cropRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))

        guard cropRect.width > 8, cropRect.height > 8,
              let cropped = source.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped).chartAgentJPEGData(maxDimension: 2200)
    }
}

private enum CropHandle: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }
    var movesLeft: Bool { self == .topLeft || self == .bottomLeft }
    var movesTop: Bool { self == .topLeft || self == .topRight }

    var accessibilityLabel: String {
        AppLanguage.localized("선택 영역")
    }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

private extension UIImage {
    func chartAgentNormalizedImage() -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
