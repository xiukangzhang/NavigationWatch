import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

enum AMapShareTarget: Equatable, Sendable {
    case destination(NavigationPlace)
    case poiID(String)
    case shortLink(URL)
}
enum AMapShareError: LocalizedError {
    case invalidLink, unsupportedCoordinates, unsupportedMode, cannotResolve, tooManyRedirects
    var errorDescription: String? {
        switch self {
        case .invalidLink: return "请粘贴有效的高德地点或驾车路线分享链接。"
        case .unsupportedCoordinates: return "该链接坐标格式暂不支持，请改用高德地点分享。"
        case .unsupportedMode: return "当前只支持驾车导航，请分享驾车路线或地点。"
        case .cannotResolve: return "未能读取分享目的地，请检查网络或重新复制链接。"
        case .tooManyRedirects: return "分享链接跳转过多，请重新复制。"
        }
    }
}

/// SDK-specific link formats stay outside Shared. External input never starts navigation.
enum AMapShareParser {
    static func url(in text: String) throws -> URL {
        guard text.utf8.count <= 16_384 else { throw AMapShareError.invalidLink }
        let pattern = #"(?:https?://|iosamap://|navigationwatch://)[^\s<>\[\]）)]+"#
        let expression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text), let url = URL(string: String(text[range])) else { throw AMapShareError.invalidLink }
        return url
    }
    static func allowedWebURL(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https", c.user == nil, c.password == nil,
              c.port == nil || c.port == 443, let host = c.host?.lowercased() else { return false }
        return host == "amap.com" || host.hasSuffix(".amap.com")
    }
    static func parse(_ url: URL) throws -> AMapShareTarget {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw AMapShareError.invalidLink }
        let scheme = c.scheme?.lowercased()
        if scheme == "navigationwatch", c.host == "import" {
            guard let inner = c.queryItems?.first(where: { $0.name == "url" })?.value,
                  let nested = URL(string: inner), nested.scheme?.lowercased() != "navigationwatch" else { throw AMapShareError.invalidLink }
            return try parse(nested)
        }
        let native = scheme == "iosamap"
        guard native || allowedWebURL(url) else { throw AMapShareError.invalidLink }
        var q: [String: String] = [:]
        for item in c.queryItems ?? [] {
            // Duplicate routing keys are ambiguous; reject instead of choosing an arbitrary destination.
            let key = item.name.lowercased()
            guard q[key] == nil else { throw AMapShareError.invalidLink }
            q[key] = item.value ?? ""
        }
        if let mode = q["mode"] ?? q["naviby"], !mode.isEmpty, mode != "car" { throw AMapShareError.unsupportedMode }
        if q["coordinate"] == "wgs84" || q["dev"] == "1" { throw AMapShareError.unsupportedCoordinates }
        if native {
            guard c.host == "navi" || c.host == "path" else { throw AMapShareError.invalidLink }
            if c.host == "path", let mode = q["t"], mode != "0" { throw AMapShareError.unsupportedMode }
            if let lat = q["dlat"] ?? q["lat"], let lon = q["dlon"] ?? q["lon"] {
                return try destination(lat: lat, lon: lon, name: q["dname"] ?? q["poiname"])
            }
        }
        // Current wb.amap.com route sharing, observed via the supplied short-link's 302.
        // Its r tuple uses latitude,longitude,name for origin and then destination.
        if c.host?.lowercased() == "wb.amap.com", let route = q["r"] {
            let fields = route.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 6 else { throw AMapShareError.invalidLink }
            return try destination(lat: fields[3], lon: fields[4], name: fields[5])
        }
        // Current wb.amap.com place sharing: POI ID, latitude, longitude, name, address.
        if c.host?.lowercased() == "wb.amap.com", let point = q["p"] {
            let fields = point.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4 else { throw AMapShareError.invalidLink }
            return try destination(lat: fields[1], lon: fields[2], name: fields[3])
        }
        if let pair = q["to"] ?? q["dest"] ?? q["position"] {
            let fields = pair.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2 else { throw AMapShareError.invalidLink }
            return try destination(lat: fields[1], lon: fields[0], name: q["destname"] ?? q["name"] ?? (fields.count > 2 ? fields[2] : nil))
        }
        if let id = q["poiid"] ?? q["id"], id.range(of: #"^B[A-Za-z0-9]{5,30}$"#, options: .regularExpression) != nil { return .poiID(id) }
        if c.host?.lowercased() == "surl.amap.com", !c.path.isEmpty, c.path != "/" { return .shortLink(url) }
        throw AMapShareError.cannotResolve
    }
    private static func destination(lat: String, lon: String, name: String?) throws -> AMapShareTarget {
        guard let latitude = Double(lat), let longitude = Double(lon), latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { throw AMapShareError.invalidLink }
        var decoded = name ?? "分享的目的地"
        for _ in 0..<2 { if let value = decoded.removingPercentEncoding { decoded = value } }
        decoded = String(decoded.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        return .destination(NavigationPlace(id: UUID().uuidString, name: decoded.isEmpty ? "分享的目的地" : decoded,
            latitude: latitude, longitude: longitude, coordinateReference: .gcj02))
    }
}

private final class NoShareRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
struct AMapShareResolver {
    func resolve(_ text: String) async throws -> AMapShareTarget {
        var target = try AMapShareParser.parse(AMapShareParser.url(in: text))
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false; config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoShareRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        for _ in 0..<5 {
            try Task.checkCancellation()
            guard case let .shortLink(url) = target else { return target }
            guard AMapShareParser.allowedWebURL(url) else { throw AMapShareError.invalidLink }
            var request = URLRequest(url: url); request.httpMethod = "HEAD"
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (300...399).contains(http.statusCode),
                  let location = http.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: url)?.absoluteURL,
                  AMapShareParser.allowedWebURL(next) else { throw AMapShareError.cannotResolve }
            target = try AMapShareParser.parse(next)
        }
        throw AMapShareError.tooManyRedirects
    }
}
