import Foundation

public struct GitLabAPIClient {

    public enum ClientError: LocalizedError {
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

    public let baseURL: URL
    public let token: String
    let session: URLSession

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

    static func runTokenCommand(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ClientError.missingEnvironment("GITLAB_TOKEN_COMMAND execution failed: \(error.localizedDescription)")
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ClientError.missingEnvironment("GITLAB_TOKEN_COMMAND failed: \(detail)")
        }

        let token = (String(data: outData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ClientError.missingEnvironment("GITLAB_TOKEN_COMMAND produced no output")
        }
        return token
    }

    public func request(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = apiURL(apiPath: "/api/v4/\(trimmed)", queryItems: queryItems) else {
            completion(.failure(ClientError.invalidURL(path)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.httpBody = body

        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(ClientError.invalidResponse))
                return
            }

            completion(.success((data!, http)))
        }.resume()
    }

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

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = [], completion: @escaping (Result<T, Error>) -> Void) {
        self.request(path: path, method: "GET", queryItems: queryItems) { result in
            switch result {
            case .success((let data, let response)):
                do {
                    try self.checkResponse(response, data: data)
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B, completion: @escaping (Result<T, Error>) -> Void) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try! encoder.encode(body)
        self.request(path: path, method: "POST", body: bodyData) { result in
            switch result {
            case .success((let data, let response)):
                do {
                    try self.checkResponse(response, data: data)
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func put<T: Decodable, B: Encodable>(path: String, body: B, completion: @escaping (Result<T, Error>) -> Void) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try! encoder.encode(body)
        self.request(path: path, method: "PUT", body: bodyData) { result in
            switch result {
            case .success((let data, let response)):
                do {
                    try self.checkResponse(response, data: data)
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func delete(path: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.request(path: path, method: "DELETE") { result in
            switch result {
            case .success((let data, let response)):
                do {
                    try self.checkResponse(response, data: data)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func checkResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(response.statusCode)"
            throw ClientError.apiError(response.statusCode, msg)
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }

    static func encodePath(_ path: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }
}

// MARK: - User Methods

extension GitLabAPIClient {
    public func currentUser(completion: @escaping (Result<GLUser, Error>) -> Void) {
        self.get(path: "user", completion: completion)
    }
}
