import Foundation
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif
#if canImport(AMapSearchKit) && canImport(AMapFoundationKit)
import AMapSearchKit
import AMapFoundationKit

@MainActor final class AMapDestinationSearch: NSObject, AMapSearchDelegate {
    private let service: AMapSearchAPI
    private var pending: CheckedContinuation<[NavigationPlace], Error>?
    private var requestID: ObjectIdentifier?
    private var timeout: Task<Void, Never>?
    init(apiKey: String, privacyAccepted: Bool) throws {
        guard privacyAccepted, !apiKey.isEmpty, !apiKey.contains("$(") else { throw NavigationError.providerAuthorizationFailed }
        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)
        AMapServices.shared().apiKey = apiKey
        guard let service = AMapSearchAPI() else { throw NavigationError.providerUnavailable }
        self.service = service
        super.init()
        service.delegate = self
        service.timeout = 20
    }
    func search(_ query: String) async throws -> [NavigationPlace] {
        guard pending == nil else { throw NavigationError.providerUnavailable }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let request = AMapPOIKeywordsSearchRequest()
        request.keywords = text; request.offset = 20; request.sortrule = 1
        let id = ObjectIdentifier(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation; requestID = id
                timeout = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(25))
                    guard !Task.isCancelled, self?.requestID == id else { return }
                    self?.complete(.failure(NavigationError.networkUnavailable), id: id)
                    self?.service.cancelAllRequests()
                }
                service.aMapPOIKeywordsSearch(request)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.requestID == id else { return }
                self?.cancel()
            }
        }
    }
    func searchID(_ query: String) async throws -> [NavigationPlace] {
        guard pending == nil else { throw NavigationError.providerUnavailable }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let request = AMapPOIIDSearchRequest()
        request.uid = text
        let id = ObjectIdentifier(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation; requestID = id
                timeout = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(25))
                    guard !Task.isCancelled, self?.requestID == id else { return }
                    self?.complete(.failure(NavigationError.networkUnavailable), id: id)
                    self?.service.cancelAllRequests()
                }
                service.aMapPOIIDSearch(request)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.requestID == id else { return }
                self?.cancel()
            }
        }
    }
    func cancel() {
        guard let id = requestID else { return }
        complete(.failure(CancellationError()), id: id)
        service.cancelAllRequests()
    }
    private func complete(_ result: Result<[NavigationPlace], Error>, id: ObjectIdentifier) {
        guard requestID == id, let continuation = pending else { return }
        pending = nil; requestID = nil
        timeout?.cancel(); timeout = nil
        continuation.resume(with: result)
    }
    nonisolated func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        guard let request, let response else { return }
        let id = ObjectIdentifier(request)
        let values = (response.pois ?? []).compactMap { poi -> NavigationPlace? in
            guard let point = poi.location else { return nil }
            let lat = Double(point.latitude), lon = Double(point.longitude)
            guard lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
            return NavigationPlace(id: poi.uid ?? UUID().uuidString, name: poi.name ?? "地点",
                latitude: lat, longitude: lon, coordinateReference: .gcj02, address: poi.address)
        }
        Task { @MainActor [weak self] in self?.complete(.success(values), id: id) }
    }
    nonisolated func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        guard let request = request as AnyObject?, let error else { return }
        let id = ObjectIdentifier(request)
        let code = (error as NSError).code
        Task { @MainActor [weak self] in self?.complete(.failure(AMapSearchFailure(code: code)), id: id) }
    }
}
private struct AMapSearchFailure: LocalizedError {
    let code: Int
    var errorDescription: String? { "搜索失败，请检查网络或稍后重试。（高德错误码 \(code)）" }
}
#else
@MainActor final class AMapDestinationSearch {
    init(apiKey: String, privacyAccepted: Bool) throws { throw NavigationError.providerUnavailable }
    func search(_ query: String) async throws -> [NavigationPlace] { throw NavigationError.providerUnavailable }
    func searchID(_ query: String) async throws -> [NavigationPlace] { throw NavigationError.providerUnavailable }
    func cancel() {}
}
#endif
