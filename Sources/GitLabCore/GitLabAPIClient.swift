import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Client

public struct GitLabAPIClient: Sendable {

    // MARK: Errors

    public enum ClientError: LocalizedError, Sendable {
        case missingEnvironment(String)
        case invalidURL(String)
        case invalidResponse
        case apiError(Int, String)
        case tokenCommandFailed(String)
        case graphQLError(String)

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
            case .tokenCommandFailed(let message):
                return message
            case .graphQLError(let message):
                return "GraphQL error: \(message)"
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
        let tok = try Self.resolveToken(environment: environment)
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https",
              let host = url.host, !host.isEmpty else {
            throw ClientError.invalidURL(rawURL)
        }
        self.init(baseURL: url, token: tok)
    }

    // MARK: Token resolution

    /// Resolve the API token. An explicit non-empty `GITLAB_TOKEN` wins;
    /// otherwise `GITLAB_TOKEN_COMMAND` is executed and its stdout is used
    /// (so the token need never live in an env var or plaintext file).
    static func resolveToken(environment: [String: String]) throws -> String {
        if let tok = environment["GITLAB_TOKEN"], !tok.isEmpty {
            return tok
        }
        if let command = environment["GITLAB_TOKEN_COMMAND"],
           !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try runTokenCommand(command)
        }
        throw ClientError.missingEnvironment("GITLAB_TOKEN or GITLAB_TOKEN_COMMAND")
    }

    /// Run `command` via `/bin/sh -c` and return its trimmed stdout as the token.
    static func runTokenCommand(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        // Signal termination through a semaphore rather than waitUntilExit().
        // Under swift-corelibs-foundation, waitUntilExit() spins the *calling*
        // thread's RunLoop; when gl runs this from its async main that thread
        // has no RunLoop servicing the child-termination source, so it would
        // block forever on Linux. terminationHandler is delivered on a Dispatch
        // queue and needs no RunLoop, and behaves the same on Darwin.
        // Must be installed before run().
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            throw ClientError.tokenCommandFailed(
                "GITLAB_TOKEN_COMMAND could not be executed: \(error.localizedDescription)")
        }

        // Drain both pipes concurrently, so a command that writes heavily to
        // stderr cannot fill that pipe while we are blocked reading stdout
        // (and vice versa).
        let outBox = LockedData()
        let errBox = LockedData()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "gl.token-command", attributes: .concurrent)
        queue.async(group: group) { outBox.value = stdout.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errBox.value = stderr.fileHandleForReading.readDataToEndOfFile() }
        group.wait()
        exited.wait()

        let outData = outBox.value
        let errData = errBox.value

        guard process.terminationStatus == 0 else {
            let detail = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let suffix = detail.isEmpty ? "" : ": \(detail)"
            throw ClientError.tokenCommandFailed(
                "GITLAB_TOKEN_COMMAND exited with status \(process.terminationStatus)\(suffix)")
        }

        let token = (String(data: outData, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ClientError.tokenCommandFailed("GITLAB_TOKEN_COMMAND produced no output")
        }
        return token
    }

    // MARK: Raw request

    public func request(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = apiURL(apiPath: "/api/v4/\(trimmed)", queryItems: queryItems) else {
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

    /// Build an absolute API URL from `baseURL`, normalising a trailing
    /// `/api/v4` and trailing slashes away so both `https://host` and
    /// `https://host/api/v4` resolve correctly. `apiPath` is inserted verbatim
    /// via `percentEncodedPath` (callers pre-encode path segments).
    private func apiURL(apiPath: String, queryItems: [URLQueryItem] = []) -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        var basePath = baseURL.path
        while basePath.hasSuffix("/") { basePath.removeLast() }
        if basePath.hasSuffix("/api/v4") { basePath.removeLast("/api/v4".count) }
        components.percentEncodedPath = "\(basePath)\(apiPath)"
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    // MARK: GraphQL

    /// Execute a GraphQL query/mutation against `<base>/api/graphql` and return
    /// the pretty-printed `data` object. `variablesJSON`, if provided, must be a
    /// JSON object string. Top-level GraphQL `errors` are surfaced as a thrown
    /// `ClientError.graphQLError`. (GraphQL lives at `/api/graphql`, not `/api/v4`.)
    public func graphQL(query: String, variablesJSON: String? = nil) async throws -> Data {
        guard let url = apiURL(apiPath: "/api/graphql") else {
            throw ClientError.invalidURL("graphql")
        }

        var bodyObject: [String: Any] = ["query": query]
        if let vj = variablesJSON, !vj.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let variables = try? JSONSerialization.jsonObject(with: Data(vj.utf8)),
                  variables is [String: Any] else {
                throw ClientError.graphQLError("--variables must be a JSON object")
            }
            bodyObject["variables"] = variables
        }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyObject)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // GitLab's GraphQL docs use `Authorization: Bearer`; PRIVATE-TOKEN also
        // works for PATs. Send both for maximum compatibility across versions.
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = bodyData

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        try checkResponse(http, data: data)

        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.invalidResponse
        }
        if let errors = envelope["errors"] as? [[String: Any]], !errors.isEmpty {
            let messages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
            throw ClientError.graphQLError(messages.isEmpty ? "GraphQL request returned errors" : messages)
        }
        let dataField = envelope["data"] ?? NSNull()
        return try JSONSerialization.data(withJSONObject: dataField, options: [.prettyPrinted, .sortedKeys])
    }

    /// Convenience overload that serialises `variables` to JSON safely (avoids
    /// string-interpolating untrusted values like project paths into the body).
    func graphQL(query: String, variables: [String: Any]) async throws -> Data {
        let vjson = String(data: try JSONSerialization.data(withJSONObject: variables), encoding: .utf8)
        return try await graphQL(query: query, variablesJSON: vjson)
    }

    /// Decode a GraphQL `data` payload into a typed value using the shared decoder.
    func graphQLDecode<T: Decodable>(query: String, variables: [String: Any]) async throws -> T {
        let data = try await graphQL(query: query, variables: variables)
        return try Self.decode(data)
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

// MARK: - Concurrency helpers

/// A lock-guarded `Data` box, used to collect pipe output from background
/// queues without tripping Swift 6 strict-concurrency checks.
final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); defer { lock.unlock() }; storage = newValue }
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
