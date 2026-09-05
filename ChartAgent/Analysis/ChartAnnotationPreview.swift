#if DEBUG
import SwiftUI
import UIKit

struct ChartAnnotationPreview: View {
    @EnvironmentObject private var analysisStore: AnalysisStore
    @State private var record: AnalysisRecord?
    @State private var imageData: Data?
    @State private var failure: String?

    var body: some View {
        Group {
            if let record, let imageData {
                AnalysisResultView(record: record, imageData: imageData, onClose: {})
            } else if let failure {
                Text(verbatim: failure).font(.caption).padding(20)
            } else {
                ProgressView().tint(ChartTheme.mint)
            }
        }
        .background(ChartTheme.background.ignoresSafeArea())
        .task { loadResult() }
    }

    @MainActor
    private func loadResult() {
        guard record == nil else { return }
        let environment = ProcessInfo.processInfo.environment
        guard let imagePath = environment["CHARTAGENT_ANNOTATION_IMAGE"],
              let recordPath = environment["CHARTAGENT_ANNOTATION_RECORD"] else {
            failure = "Set CHARTAGENT_ANNOTATION_IMAGE and CHARTAGENT_ANNOTATION_RECORD to local QA files."
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let resultData = try Data(contentsOf: URL(fileURLWithPath: recordPath))
            let loaded = try decoder.decode(AnalysisRecord.self, from: resultData)
            let loadedImage = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            if let annotationPath = environment["CHARTAGENT_ANNOTATION_DOCUMENT"] {
                let data = try Data(contentsOf: URL(fileURLWithPath: annotationPath))
                let document = try decoder.decode(ChartAnnotationDocument.self, from: data)
                guard document.isValid, document.locale == AppLanguage.current.responseLanguage else {
                    failure = "The annotation locale or geometry does not match the preview request."
                    return
                }
                let key = ChartAnnotationDocument.cacheKey(analysisID: loaded.id, locale: document.locale)
                try analysisStore.saveChartAnnotations(document, key: key)
                if let exportPath = environment["CHARTAGENT_ANNOTATION_EXPORT"], let image = UIImage(data: loadedImage) {
                    let canvas = AnnotatedChartCanvas(image: image, annotations: document.annotations,
                                                     selectedID: .constant(document.annotations.first?.id), expanded: true)
                        .frame(width: image.size.width / 2, height: image.size.height / 2)
                    let renderer = ImageRenderer(content: canvas)
                    renderer.scale = 2
                    if let png = renderer.uiImage?.pngData() {
                        try png.write(to: URL(fileURLWithPath: exportPath), options: .atomic)
                    }
                }
            }
            imageData = loadedImage
            record = loaded
        } catch {
            failure = error.localizedDescription
        }
    }
}
#endif
