import Foundation

// MARK: - Client

public struct GitLabAPIClient: Sendable {

    // MARK: Errors

    public enum ClientError: LocalizedError, Sendable {
        case missingEnvironment(String)
        case invalidURL(String)
        case invalidResponse
        case apiError(Int, String)

        public var errorDescription: String? {
            switch self {
            case .missingEnvironment(let key):
                return "Missing required environment variable: \(key)"
            case .invalidURL(let value):
                return "Invalid GitLab API URL: \(value)"
            case .invalidResponse:
                return "GitLab API returned an invalid response"
            case .apiError(let code, let message):
                return "GitLab API error \(code): \(message)"
            }
        }
    }

    // MARK: Properties

    public let baseURL: URL
    public let token: String
    let session: URLSession

    // MARK: Initializers

    public init(baseURL: URL, token: String, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public init(environment: [String: String]) throws {
        guard let rawURL = environment["GITLAB_API_URL"], !rawURL.isEmpty else {
            throw ClientError.missingEnvironment("GITLAB_API_URL")
        }
        guard let tok = environment["GITLAB_TOKEN"], !tok.isEmpty else {
            throw ClientError.missingEnvironment("GITLAB_TOKEN")
        }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https" else {
            throw ClientError.invalidURL(rawURL)
        }
        self.init(baseURL: url, token: tok)
    }

    // MARK: Raw request

    public func request(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        // Use percentEncodedPath so encodePath's %2F isn't double-encoded by appending(path:)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        let basePath = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
        components.percentEncodedPath = "\(basePath)/api/v4/\(trimmed)"
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw ClientError.invalidURL(path)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        return (data, http)
    }

    // MARK: Typed helpers

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let (data, response) = try await request(path: path, queryItems: queryItems)
        try checkResponse(response, data: data)
        return try Self.decode(data)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let bodyData = try Self.encode(body)
        let (data, response) = try await request(path: path, method: "POST", body: bodyData)
        try checkResponse(response, data: data)
        return try Self.decode(data)
    }

    func put<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let bodyData = try Self.encode(body)
        let (data, response) = try await request(path: path, method: "PUT", body: bodyData)
        try checkResponse(response, data: data)
        return try Self.decode(data)
    }

    func delete(path: String) async throws {
        let (data, response) = try await request(path: path, method: "DELETE")
        try checkResponse(response, data: data)
    }

    // MARK: Internals

    func checkResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(response.statusCode)"
            throw ClientError.apiError(response.statusCode, msg)
        }
    }

    static func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            for fmt in [ISO8601DateFormatter.withFractional, ISO8601DateFormatter.plain] {
                if let d = fmt.date(from: s) { return d }
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported date: \(s)")
        }
        return try decoder.decode(T.self, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }

    // URL-encode a project/group path for use in REST paths
    static func encodePath(_ path: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }
}

// MARK: - Date formatters

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

// MARK: - Pretty JSON helper

extension Encodable {
    /// Re-encode as pretty-printed JSON string (snake_case keys, sorted).
    public func prettyJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
