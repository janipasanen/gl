import XCTest
@testable import GitLabCore

final class SnippetAPITests: XCTestCase {

    func testListSnippets() async throws {
        stubRaw(json: Fixtures.snippetsArrayJSON)
        let client = makeTestClient()
        let snippets = try await client.listSnippets(project: "mygroup/my-project")
        XCTAssertEqual(snippets.count, 1)
        let s = snippets[0]
        XCTAssertEqual(s.id, 17)
        XCTAssertEqual(s.title, "Quick fix")
        XCTAssertEqual(s.fileName, "fix.swift")
        XCTAssertEqual(s.visibility, "private")
        XCTAssertEqual(s.author?.username, "asmith")
        XCTAssertEqual(s.files?.first?.path, "fix.swift")
    }

    func testGetSnippet() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.snippetJSON.utf8))
        }
        let client = makeTestClient()
        let s = try await client.getSnippet(project: "mygroup/my-project", snippetId: 17)
        XCTAssertEqual(s.id, 17)
        XCTAssertTrue(capturedURL?.absoluteString.contains("/snippets/17") == true)
    }

    func testCreateSnippet() async throws {
        var capturedBody: [String: Any]?
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.snippetJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateSnippetParams(
            title: "Quick fix", fileName: "fix.swift", content: "print(1)",
            description: "A handy snippet", visibility: "private"
        )
        let s = try await client.createSnippet(project: "p", params: params)
        XCTAssertEqual(s.id, 17)
        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedBody?["title"] as? String, "Quick fix")
        XCTAssertEqual(capturedBody?["file_name"] as? String, "fix.swift")
        XCTAssertEqual(capturedBody?["content"] as? String, "print(1)")
        XCTAssertEqual(capturedBody?["visibility"] as? String, "private")
    }

    func testUpdateSnippet() async throws {
        var capturedBody: [String: Any]?
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.snippetJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateSnippetParams(title: "Renamed", content: "print(2)")
        _ = try await client.updateSnippet(project: "p", snippetId: 17, params: params)
        XCTAssertEqual(capturedMethod, "PUT")
        XCTAssertEqual(capturedBody?["title"] as? String, "Renamed")
        XCTAssertEqual(capturedBody?["content"] as? String, "print(2)")
        // nil fields must be omitted
        XCTAssertNil(capturedBody?["visibility"])
    }

    func testDeleteSnippet() async throws {
        var capturedMethod: String?
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteSnippet(project: "p", snippetId: 17)
        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertTrue(capturedURL?.absoluteString.contains("/snippets/17") == true)
    }
}
