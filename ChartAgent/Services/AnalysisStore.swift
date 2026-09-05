import Foundation

@MainActor
final class AnalysisStore: ObservableObject {
    @Published private(set) var records: [AnalysisRecord] = []
    @Published private(set) var followUpThreads: [String: [SavedFollowUpTurn]] = [:]
    @Published private(set) var chartAnnotations: [String: ChartAnnotationDocument] = [:]

    private let fileManager: FileManager
    private let rootURL: URL
    private let recordsURL: URL
    private let followUpsURL: URL
    private let imagesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let annotationRequest: (Data, AnalysisPayload, String) async throws -> ChartAnnotationDocument
    private var annotationTasks: [String: Task<ChartAnnotationDocument, Error>] = [:]

    init(fileManager: FileManager = .default, storageDirectory: URL? = nil,
         annotationRequest: @escaping (Data, AnalysisPayload, String) async throws -> ChartAnnotationDocument = {
             try await ChartAgentAPI.shared.chartAnnotations(imageData: $0, analysis: $1, locale: $2)
         }) {
        self.fileManager = fileManager
        self.annotationRequest = annotationRequest
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = storageDirectory ?? support.appending(path: "ChartAgent", directoryHint: .isDirectory)
        recordsURL = rootURL.appending(path: "analyses.json")
        followUpsURL = rootURL.appending(path: "follow-ups.json")
        imagesURL = rootURL.appending(path: "Images", directoryHint: .isDirectory)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        load()
        if let data = try? Data(contentsOf: annotationsURL),
           let saved = try? decoder.decode([String: ChartAnnotationDocument].self, from: data) {
            chartAnnotations = saved.filter { $0.value.isValid }
        }
    }

    var latest: AnalysisRecord? { records.first }

    func save(_ record: AnalysisRecord, imageData: Data) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        if records.count > 30 { records.removeLast(records.count - 30) }
        do {
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            try imageData.write(to: imageURL(for: record.id), options: .atomic)
            try persist()
        } catch {
            assertionFailure("Analysis persistence failed: \(error.localizedDescription)")
        }
    }

    func imageData(for record: AnalysisRecord) -> Data? {
        try? Data(contentsOf: imageURL(for: record.id))
    }

    func saveChartAnnotations(_ document: ChartAnnotationDocument, key: String) throws {
        chartAnnotations[key] = document
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try encoder.encode(chartAnnotations).write(to: annotationsURL, options: .atomic)
    }

    private var annotationsURL: URL { rootURL.appending(path: "chart-annotations.json") }

    @discardableResult
    func prepareChartAnnotations(analysisID: String, imageData: Data, analysis: AnalysisPayload,
                                 locale: String, retry: Bool = false) -> Task<ChartAnnotationDocument, Error> {
        let key = ChartAnnotationDocument.cacheKey(analysisID: analysisID, locale: locale)
        if let cached = chartAnnotations[key], cached.locale == locale,
           cached.hasValidScenarioLinks(count: analysis.scenarios.count) {
            return Task { cached }
        }
        if let running = annotationTasks[key], !retry { return running }
        annotationTasks[key]?.cancel()
        let request = annotationRequest
        let task = Task { [weak self] in
            let document = try await request(imageData, analysis, locale)
            try Task.checkCancellation()
            try? self?.saveChartAnnotations(document, key: key)
            self?.annotationTasks.removeValue(forKey: key)
            return document
        }
        annotationTasks[key] = task
        return task
    }

    func followUpTurns(for analysisID: String) -> [SavedFollowUpTurn] {
        followUpThreads[analysisID, default: []].sorted { $0.createdAt < $1.createdAt }
    }

    func saveFollowUpTurn(_ turn: SavedFollowUpTurn) {
        var thread = followUpThreads[turn.analysisId, default: []]
        thread.removeAll { $0.id == turn.id }
        thread.append(turn)
        followUpThreads[turn.analysisId] = Array(thread.sorted { $0.createdAt < $1.createdAt }.suffix(40))
        do {
            try persistFollowUps()
        } catch {
            assertionFailure("Follow-up persistence failed: \(error.localizedDescription)")
        }
    }

    func remove(_ record: AnalysisRecord) {
        for key in Array(annotationTasks.keys) where key.hasPrefix(record.id + ":") {
            annotationTasks.removeValue(forKey: key)?.cancel()
        }
        records.removeAll { $0.id == record.id }
        followUpThreads.removeValue(forKey: record.id)
        chartAnnotations = chartAnnotations.filter { !$0.key.hasPrefix(record.id + ":") }
        try? encoder.encode(chartAnnotations).write(to: annotationsURL, options: .atomic)
        try? fileManager.removeItem(at: imageURL(for: record.id))
        try? persist()
        try? persistFollowUps()
    }

    func removeAllAnalyses() {
        annotationTasks.values.forEach { $0.cancel() }
        annotationTasks.removeAll()
        records.removeAll()
        followUpThreads.removeAll()
        chartAnnotations.removeAll()
        try? fileManager.removeItem(at: annotationsURL)
        do {
            if fileManager.fileExists(atPath: imagesURL.path()) {
                try fileManager.removeItem(at: imagesURL)
            }
            try persist()
            try persistFollowUps()
        } catch {
            assertionFailure("Analysis reset failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: recordsURL),
              let decoded = try? decoder.decode([AnalysisRecord].self, from: data) else {
            loadFollowUps()
            return
        }
        records = decoded.sorted { $0.createdAt > $1.createdAt }
        loadFollowUps()
    }

    private func persist() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try encoder.encode(records).write(to: recordsURL, options: .atomic)
    }

    private func loadFollowUps() {
        guard let data = try? Data(contentsOf: followUpsURL),
              let decoded = try? decoder.decode([String: [SavedFollowUpTurn]].self, from: data) else { return }
        followUpThreads = decoded
    }

    private func persistFollowUps() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try encoder.encode(followUpThreads).write(to: followUpsURL, options: .atomic)
    }

    private func imageURL(for id: String) -> URL {
        imagesURL.appending(path: "\(id).jpg")
    }
}
