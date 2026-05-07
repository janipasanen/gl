import XCTest
@testable import GitLabCore

final class ReleaseAPITests: XCTestCase {

    func testListReleases() async throws {
        stubRaw(json: Fixtures.releasesArrayJSON)
        let client = makeTestClient()
        let releases = try await client.listReleases(project: "mygroup/my-project")
        XCTAssertEqual(releases.count, 1)
        let r = releases[0]
        XCTAssertEqual(r.tagName, "v1.0.0")
        XCTAssertEqual(r.name, "Version 1.0.0")
    }

    func testGetRelease() async throws {
        stubRaw(json: Fixtures.releaseJSON)
        let client = makeTestClient()
        let r = try await client.getRelease(project: "p", tagName: "v1.0.0")
        XCTAssertEqual(r.tagName, "v1.0.0")
        XCTAssertEqual(r.author?.username, "jdoe")
    }

    func testCreateRelease() async throws {
        stubRaw(status: 201, json: Fixtures.releaseJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.releaseJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateReleaseParams(tagName: "v1.0.0", name: "Version 1.0.0", description: "First stable release")
        let r = try await client.createRelease(project: "p", params: params)
        XCTAssertEqual(r.tagName, "v1.0.0")
        XCTAssertEqual(capturedBody?["tag_name"] as? String, "v1.0.0")
        XCTAssertEqual(capturedBody?["name"] as? String, "Version 1.0.0")
        XCTAssertNil(capturedBody?["ref"])
    }

    func testDeleteRelease() async throws {
        stubRaw(json: Fixtures.releaseJSON)
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.releaseJSON.utf8))
        }
        let client = makeTestClient()
        let r = try await client.deleteRelease(project: "p", tagName: "v1.0.0")
        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(r.tagName, "v1.0.0")
    }

    func testUpdateRelease() async throws {
        stubRaw(json: Fixtures.releaseJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.releaseJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.updateRelease(project: "p", tagName: "v1.0.0", name: "Version 1.0.0 (patched)")
        XCTAssertEqual(capturedBody?["name"] as? String, "Version 1.0.0 (patched)")
    }
}
