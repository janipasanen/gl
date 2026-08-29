import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class BranchAPITests: XCTestCase {

    func testListBranches() async throws {
        stubRaw(json: Fixtures.branchesArrayJSON)
        let client = makeTestClient()
        let branches = try await client.listBranches(project: "mygroup/my-project")
        XCTAssertEqual(branches.count, 1)
        let b = branches[0]
        XCTAssertEqual(b.name, "main")
        XCTAssertTrue(b.isDefault)
        XCTAssertTrue(b.protected)
        XCTAssertFalse(b.merged)
        XCTAssertEqual(b.commit?.shortId, "abc123de")
    }

    func testListBranchesSearch() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.branchesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listBranches(project: "p", search: "feat")
        XCTAssertTrue(capturedQuery?.contains("search=feat") == true)
    }

    func testGetBranch() async throws {
        stubRaw(json: Fixtures.branchJSON)
        let client = makeTestClient()
        let b = try await client.getBranch(project: "p", branch: "main")
        XCTAssertEqual(b.name, "main")
        XCTAssertTrue(b.isDefault)
    }

    func testCreateBranch() async throws {
        stubRaw(status: 201, json: Fixtures.branchJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.branchJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateBranchParams(branch: "feature/new", ref: "main")
        let b = try await client.createBranch(project: "p", params: params)
        XCTAssertEqual(b.name, "main")  // fixture returns "main"
        XCTAssertEqual(capturedBody?["branch"] as? String, "feature/new")
        XCTAssertEqual(capturedBody?["ref"] as? String, "main")
    }

    func testDeleteBranch() async throws {
        var capturedMethod: String?
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteBranch(project: "p", branch: "feature/old")
        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertTrue(capturedURL?.path.contains("feature") == true)
    }
}
