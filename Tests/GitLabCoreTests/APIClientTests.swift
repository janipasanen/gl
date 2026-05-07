import XCTest
@testable import GitLabCore

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
}
