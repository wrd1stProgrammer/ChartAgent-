import Foundation
import Combine
import UIKit

enum AnalysisRequestTiming {
    static let maximumDuration: TimeInterval = 120
    static let pollingInterval: TimeInterval = 2
}

@MainActor
final class AnalysisRunCoordinator: ObservableObject {
    @Published private(set) var activeDraft: AnalysisDraft?

    private var draftID: UUID?
    private var runTask: Task<AnalysisRecord, Error>?
    private var completedRecord: AnalysisRecord?
    private var completedFailure: ChartAgentAPIError?

    func cachedResult(for draftID: UUID) -> AnalysisRecord? {
        self.draftID == draftID ? completedRecord : nil
    }

    func cachedFailure(for draftID: UUID) -> ChartAgentAPIError? {
        self.draftID == draftID ? completedFailure : nil
    }

    func prepare(_ draft: AnalysisDraft) {
        guard draftID != draft.id else {
            activeDraft = draft
            return
        }
        reset()
        draftID = draft.id
        activeDraft = draft
    }

    func analyze(_ draft: AnalysisDraft) async throws -> AnalysisRecord {
        if draftID != draft.id {
            prepare(draft)
        }
        if let completedRecord { return completedRecord }
        if let completedFailure { throw completedFailure }

        if runTask == nil {
            let backgroundTask = UIApplication.shared.beginBackgroundTask(
                withName: "ChartAgent analysis"
            )
            runTask = Task.detached(priority: .userInitiated) {
                defer {
                    if backgroundTask != .invalid {
                        DispatchQueue.main.async {
                            UIApplication.shared.endBackgroundTask(backgroundTask)
                        }
                    }
                }
                return try await ChartAgentAPI.shared.analyze(draft)
            }
        }

        guard let runTask else { throw ChartAgentAPIError.invalidResponse }
        do {
            let record = try await runTask.value
            completedRecord = record
            completedFailure = nil
            self.runTask = nil
            return record
        } catch is CancellationError {
            // The view waiting for the request may disappear while iOS briefly
            // backgrounds the app. Keep the independent task alive so a new
            // session view can reattach to it on return.
            throw CancellationError()
        } catch let error as ChartAgentAPIError {
            completedFailure = error
            completedRecord = nil
            self.runTask = nil
            throw error
        } catch {
            let normalized = ChartAgentAPIError.transport(error.localizedDescription)
            completedFailure = normalized
            completedRecord = nil
            self.runTask = nil
            throw normalized
        }
    }

    func reset() {
        runTask?.cancel()
        runTask = nil
        draftID = nil
        activeDraft = nil
        completedRecord = nil
        completedFailure = nil
    }
}

struct ChartAgentAPI {
    static let shared = ChartAgentAPI()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared, baseURL: URL = AppConfiguration.apiBaseURL) {
        self.session = session
        self.baseURL = baseURL
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    func searchSymbols(query: String) async throws -> [MarketSymbol] {
        var components = URLComponents(url: baseURL.appending(path: "symbols/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "query", value: query)]
        guard let url = components?.url else { throw ChartAgentAPIError.invalidResponse }
        let payload: SymbolSearchPayload = try await send(URLRequest(url: url))
        return payload.symbols
    }

    func analyze(_ draft: AnalysisDraft) async throws -> AnalysisRecord {
        let deadline = Date().addingTimeInterval(AnalysisRequestTiming.maximumDuration)
        let boundary = "ChartAgent-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "analysis-jobs"))
        request.httpMethod = "POST"
        request.timeoutInterval = min(30, max(1, deadline.timeIntervalSinceNow))
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(draft: draft, boundary: boundary)
        let accepted: AnalysisJobAccepted = try await send(request)
        return try await waitForAnalysisJob(accepted.jobId, deadline: deadline)
    }

    func chartAnnotations(imageData: Data, analysis: AnalysisPayload, locale: String) async throws -> ChartAnnotationDocument {
        let boundary = "ChartAnnotation-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.deletingLastPathComponent().appending(path: "v2/chart-annotations"))
        request.httpMethod = "POST"
        request.timeoutInterval = 130
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let context = try encoder.encode(ChartAnnotationContext(analysis: analysis))
        var body = Data()
        for (name, value) in [("locale", locale), ("report_context", String(decoding: context, as: UTF8.self))] {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"chart.jpg\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let document: ChartAnnotationDocument = try await send(request)
        guard document.isValid, document.locale == locale,
              document.hasValidScenarioLinks(count: analysis.scenarios.count) else { throw ChartAgentAPIError.invalidResponse }
        return document
    }

    func followUp(
        agentID: String,
        question: String,
        analysis: AnalysisRecord,
        history: [FollowUpHistoryItem]
    ) async throws -> FollowUpResponse {
        struct RequestBody: Encodable {
            let agentId: String
            let question: String
            let analysis: AnalysisRecord
            let history: [FollowUpHistoryItem]
            let responseLanguage: String
            let agentProfile: AgentProfileSnapshot?
        }
        var request = URLRequest(url: baseURL.appending(path: "follow-ups"))
        request.httpMethod = "POST"
        request.timeoutInterval = 130
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            RequestBody(
                agentId: agentID,
                question: question,
                analysis: analysis,
                history: history,
                responseLanguage: Self.responseLanguage,
                agentProfile: analysis.agentProfiles?
                    .first { $0.roleID == agentID }?
                    .localizedForRequest
            )
        )
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ChartAgentAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
                    throw ChartAgentAPIError.server(payload)
                }
                throw ChartAgentAPIError.server(
                    APIErrorPayload(
                        code: "http_\(http.statusCode)",
                        message: AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다."),
                        recovery: AppLanguage.localized("잠시 후 다시 시도해 주세요.")
                    )
                )
            }
            return try decoder.decode(Response.self, from: data)
        } catch let error as ChartAgentAPIError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw ChartAgentAPIError.server(
                    APIErrorPayload(
                        code: "http_504",
                        message: AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다."),
                        recovery: AppLanguage.localized("잠시 후 다시 시도해 주세요.")
                    )
                )
            }
            throw ChartAgentAPIError.transport(error.localizedDescription)
        } catch {
            throw ChartAgentAPIError.invalidResponse
        }
    }

    private func waitForAnalysisJob(_ jobID: String, deadline: Date) async throws -> AnalysisRecord {
        while Date() < deadline {
            try Task.checkCancellation()
            var request = URLRequest(url: baseURL.appending(path: "analysis-jobs/\(jobID)"))
            request.timeoutInterval = min(20, max(1, deadline.timeIntervalSinceNow))
            let snapshot: AnalysisJobSnapshot = try await send(request)
            switch snapshot.status {
            case "completed":
                guard let result = snapshot.result else { throw ChartAgentAPIError.invalidResponse }
                return result
            case "failed":
                guard let error = snapshot.error else { throw ChartAgentAPIError.invalidResponse }
                throw ChartAgentAPIError.server(error)
            case "pending":
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { break }
                try await Task.sleep(
                    for: .seconds(min(AnalysisRequestTiming.pollingInterval, remaining))
                )
            default:
                throw ChartAgentAPIError.invalidResponse
            }
        }
        throw ChartAgentAPIError.server(
            APIErrorPayload(
                code: "http_504",
                message: AppLanguage.localized("분석 서버가 응답을 완료하지 못했습니다."),
                recovery: AppLanguage.localized("잠시 후 다시 시도해 주세요.")
            )
        )
    }

    private func multipartBody(draft: AnalysisDraft, boundary: String) -> Data {
        var data = Data()
        func append(_ value: String) {
            data.append(Data(value.utf8))
        }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        field("include_news", draft.includesNews ? "true" : "false")
        field("active_agent_ids", draft.activeAgentIDs.joined(separator: ","))
        field("locale", Self.responseLanguage)
        let profileSnapshots = draft.agentProfiles.map(AgentProfileSnapshot.init)
        if let profiles = try? encoder.encode(profileSnapshots),
           let profilesJSON = String(data: profiles, encoding: .utf8) {
            field("agent_profiles", profilesJSON)
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"chart.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        data.append(draft.imageData)
        append("\r\n--\(boundary)--\r\n")
        return data
    }

    private static var responseLanguage: String {
        AppLanguage.current.responseLanguage
    }
}

private struct AnalysisJobAccepted: Decodable {
    let jobId: String
}

private struct AnalysisJobSnapshot: Decodable {
    let status: String
    let result: AnalysisRecord?
    let error: APIErrorPayload?
}

private enum AppConfiguration {
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["CHARTAGENT_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "CHARTAGENT_API_BASE_URL") as? String,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "https://facemaxx.nostalgia-drive.com/chartagent/v1/")!
    }
}
