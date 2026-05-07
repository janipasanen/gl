import XCTest
@testable import GitLabCore

final class MRAPITests: XCTestCase {

    func testListMergeRequests() async throws {
        stubRaw(json: Fixtures.mrsArrayJSON)
        let client = makeTestClient()
        let mrs = try await client.listMergeRequests(project: "mygroup/my-project")
        XCTAssertEqual(mrs.count, 1)
        let mr = mrs[0]
        XCTAssertEqual(mr.iid, 3)
        XCTAssertEqual(mr.sourceBranch, "feature/x")
        XCTAssertEqual(mr.targetBranch, "main")
        XCTAssertEqual(mr.state, "opened")
    }

    func testListMRsQueryParams() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.mrsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listMergeRequests(project: "p", state: "merged", sourceBranch: "feat", targetBranch: "main", milestone: "v1")
        XCTAssertTrue(capturedQuery?.contains("state=merged") == true)
        XCTAssertTrue(capturedQuery?.contains("source_branch=feat") == true)
        XCTAssertTrue(capturedQuery?.contains("target_branch=main") == true)
        XCTAssertTrue(capturedQuery?.contains("milestone=v1") == true)
    }

    func testGetMR() async throws {
        stubRaw(json: Fixtures.mrJSON)
        let client = makeTestClient()
        let mr = try await client.getMergeRequest(project: "mygroup/my-project", iid: 3)
        XCTAssertEqual(mr.iid, 3)
        XCTAssertEqual(mr.mergeStatus, "can_be_merged")
        XCTAssertEqual(mr.draft, false)
    }

    func testCreateMR() async throws {
        stubRaw(status: 201, json: Fixtures.mrJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.mrJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateMRParams(sourceBranch: "feature/x", targetBranch: "main", title: "Add feature X")
        let mr = try await client.createMergeRequest(project: "p", params: params)
        XCTAssertEqual(mr.iid, 3)
        XCTAssertEqual(capturedBody?["source_branch"] as? String, "feature/x")
        XCTAssertEqual(capturedBody?["target_branch"] as? String, "main")
        XCTAssertEqual(capturedBody?["title"] as? String, "Add feature X")
        XCTAssertNil(capturedBody?["assignee_ids"])
    }

    func testUpdateMR() async throws {
        stubRaw(json: Fixtures.mrJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.mrJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateMRParams(title: "Updated title", stateEvent: "close")
        _ = try await client.updateMergeRequest(project: "p", iid: 3, params: params)
        XCTAssertEqual(capturedBody?["title"] as? String, "Updated title")
        XCTAssertEqual(capturedBody?["state_event"] as? String, "close")
        XCTAssertNil(capturedBody?["target_branch"])
    }

    func testCloseMR() async throws {
        stubRaw(json: Fixtures.mrJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.mrJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.closeMergeRequest(project: "p", iid: 3)
        XCTAssertEqual(capturedBody?["state_event"] as? String, "close")
    }

    func testMergeMR() async throws {
        stubRaw(json: Fixtures.mrJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.mrJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.mergeMR(project: "p", iid: 3)
        XCTAssertTrue(capturedURL?.path.contains("merge") == true)
    }

    func testMRNotesList() async throws {
        stubRaw(json: Fixtures.notesArrayJSON)
        let client = makeTestClient()
        let notes = try await client.listMRNotes(project: "p", mrIid: 3)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].id, 55)
    }

    func testMRNoteCreate() async throws {
        stubRaw(json: Fixtures.noteJSON)
        let client = makeTestClient()
        let note = try await client.createMRNote(project: "p", mrIid: 3, body: "LGTM")
        XCTAssertEqual(note.id, 55)
    }

    func testMRNoteUpdate() async throws {
        stubRaw(json: Fixtures.noteJSON)
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.noteJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.updateMRNote(project: "p", mrIid: 3, noteId: 55, body: "Updated")
        XCTAssertEqual(capturedMethod, "PUT")
    }

    func testMRNoteDelete() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteMRNote(project: "p", mrIid: 3, noteId: 55)
        XCTAssertEqual(capturedMethod, "DELETE")
    }
}
