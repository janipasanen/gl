import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class APIClientTests: XCTestCase {

    func testInitFromEnvironment() throws {
        let env = ["GITLAB_API_URL": "https://gitlab.example.com", "GITLAB_TOKEN": "secret"]
        let client = try GitLabAPIClient(environment: env)
        XCTAssertEqual(client.baseURL.absoluteString, "https://gitlab.example.com")
        XCTAssertEqual(client.token, "secret")
    }

    func testInitMissingURL() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: ["GITLAB_TOKEN": "tok"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("GITLAB_API_URL"))
        }
    }

    func testInitMissingToken() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: ["GITLAB_API_URL": "https://gitlab.example.com"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("GITLAB_TOKEN"))
        }
    }

    func testInitInvalidURL() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "not a valid url!!",
            "GITLAB_TOKEN": "tok",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid GitLab API URL"))
        }
    }

    func testRequestAddsPrivateTokenHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { req in
            capturedRequest = req
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data("{}".utf8))
        }
        let client = makeTestClient()
        _ = try await client.request(path: "user")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "PRIVATE-TOKEN"), "test-token")
    }

    func testRequestBuildsCorrectURL() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data("{}".utf8))
        }
        let client = makeTestClient()
        _ = try await client.request(path: "projects/42/issues")
        XCTAssertEqual(capturedURL?.path, "/api/v4/projects/42/issues")
    }

    func testRequestAppendsQueryItems() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data("[]".utf8))
        }
        let client = makeTestClient()
        _ = try await client.request(
            path: "projects",
            queryItems: [.init(name: "per_page", value: "5")]
        )
        XCTAssertTrue(capturedURL?.query?.contains("per_page=5") == true)
    }

    func testApiErrorThrows() async {
        stubRaw(status: 404, json: #"{"message":"Not found"}"#)
        let client = makeTestClient()
        do {
            let _: GLUser = try await client.get(path: "user")
            XCTFail("Expected error")
        } catch GitLabAPIClient.ClientError.apiError(let code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCheckResponseThrowsOn4xx() {
        let client = makeTestClient()
        let response = HTTPURLResponse(url: URL(string: "https://x.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        XCTAssertThrowsError(try client.checkResponse(response, data: Data("Forbidden".utf8))) { error in
            XCTAssertTrue(error.localizedDescription.contains("403"))
        }
    }

    func testEncodePathEscapesSlash() {
        let encoded = GitLabAPIClient.encodePath("group/project")
        // "/" should be encoded to "%2F"
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertTrue(encoded.contains("%2F"))
    }

    // MARK: - Base URL normalisation (regression for #5)

    private func capturedPath(forBaseURL base: String) async throws -> String {
        var captured: String?
        MockURLProtocol.requestHandler = { req in
            captured = req.url?.absoluteString
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data("{}".utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = GitLabAPIClient(
            baseURL: URL(string: base)!,
            token: "t",
            session: URLSession(configuration: config)
        )
        _ = try await client.request(path: "projects/42")
        return captured ?? ""
    }

    func testBaseURLWithoutApiV4Suffix() async throws {
        let url = try await capturedPath(forBaseURL: "https://gitlab.example.com")
        XCTAssertEqual(url, "https://gitlab.example.com/api/v4/projects/42")
    }

    func testBaseURLWithApiV4Suffix() async throws {
        let url = try await capturedPath(forBaseURL: "https://gitlab.example.com/api/v4")
        XCTAssertEqual(url, "https://gitlab.example.com/api/v4/projects/42")
    }

    func testBaseURLWithTrailingSlash() async throws {
        let url = try await capturedPath(forBaseURL: "https://gitlab.example.com/")
        XCTAssertEqual(url, "https://gitlab.example.com/api/v4/projects/42")
    }

    func testBaseURLWithApiV4AndTrailingSlash() async throws {
        let url = try await capturedPath(forBaseURL: "https://gitlab.example.com/api/v4/")
        XCTAssertEqual(url, "https://gitlab.example.com/api/v4/projects/42")
    }

    func testBaseURLWithSubpath() async throws {
        // self-managed GitLab served under a subpath
        let url = try await capturedPath(forBaseURL: "https://example.com/gitlab")
        XCTAssertEqual(url, "https://example.com/gitlab/api/v4/projects/42")
    }

    func testInitRejectsURLWithoutHost() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://",
            "GITLAB_TOKEN": "tok",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid GitLab API URL"))
        }
    }

    // MARK: - GITLAB_TOKEN_COMMAND (regression for #8)

    func testTokenFromCommand() throws {
        let client = try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
            "GITLAB_TOKEN_COMMAND": "echo glpat-from-command",
        ])
        // trailing newline from echo must be trimmed
        XCTAssertEqual(client.token, "glpat-from-command")
    }

    func testTokenEnvWinsOverCommand() throws {
        let client = try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
            "GITLAB_TOKEN": "explicit-token",
            "GITLAB_TOKEN_COMMAND": "echo should-not-be-used",
        ])
        XCTAssertEqual(client.token, "explicit-token")
    }

    func testTokenCommandSupportsShellSyntax() throws {
        let client = try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
            "GITLAB_TOKEN_COMMAND": "printf '%s' \"pre-$((1+1))-post\"",
        ])
        XCTAssertEqual(client.token, "pre-2-post")
    }

    func testTokenCommandNonZeroExitThrows() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
            "GITLAB_TOKEN_COMMAND": "echo nope >&2; exit 7",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("status 7"))
        }
    }

    func testTokenCommandEmptyOutputThrows() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
            "GITLAB_TOKEN_COMMAND": "true",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("no output"))
        }
    }

    func testInitMissingTokenAndCommandMentionsBoth() {
        XCTAssertThrowsError(try GitLabAPIClient(environment: [
            "GITLAB_API_URL": "https://gitlab.example.com",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("GITLAB_TOKEN"))
            XCTAssertTrue(error.localizedDescription.contains("GITLAB_TOKEN_COMMAND"))
        }
    }

    // MARK: - GraphQL transport (#9)

    func testGraphQLPostsToGraphqlEndpoint() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        var capturedBody: [String: Any]?
        var capturedAuth: String?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            capturedMethod = req.httpMethod
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{"x":1}}"#.utf8))
        }
        let client = makeTestClient()
        let data = try await client.graphQL(query: "{ x }")
        XCTAssertEqual(capturedURL?.absoluteString, "https://gitlab.example.com/api/graphql")
        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedAuth, "Bearer test-token")
        XCTAssertEqual(capturedBody?["query"] as? String, "{ x }")
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["x"] as? Int, 1)
    }

    func testGraphQLStripsApiV4FromEndpoint() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{}}"#.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = GitLabAPIClient(
            baseURL: URL(string: "https://gitlab.example.com/api/v4")!,
            token: "t",
            session: URLSession(configuration: config)
        )
        _ = try await client.graphQL(query: "{ x }")
        XCTAssertEqual(capturedURL?.absoluteString, "https://gitlab.example.com/api/graphql")
    }

    func testGraphQLSendsVariables() async throws {
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{}}"#.utf8))
        }
        let client = makeTestClient()
        _ = try await client.graphQL(query: "query($a:Int){ x(a:$a) }", variablesJSON: #"{"a":5}"#)
        let vars = capturedBody?["variables"] as? [String: Any]
        XCTAssertEqual(vars?["a"] as? Int, 5)
    }

    func testGraphQLSurfacesErrors() async {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"errors":[{"message":"Field 'bogus' doesn't exist"}]}"#.utf8))
        }
        let client = makeTestClient()
        do {
            _ = try await client.graphQL(query: "{ bogus }")
            XCTFail("expected a GraphQL error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("bogus"))
        }
    }

    func testGraphQLRejectsNonObjectVariables() async {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{}}"#.utf8))
        }
        let client = makeTestClient()
        do {
            _ = try await client.graphQL(query: "{ x }", variablesJSON: "[1,2,3]")
            XCTFail("expected variables validation to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("JSON object"))
        }
    }
}
