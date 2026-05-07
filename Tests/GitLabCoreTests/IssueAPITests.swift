import XCTest
@testable import GitLabCore

final class IssueAPITests: XCTestCase {

    func testListIssues() async throws {
        stubRaw(json: Fixtures.issuesArrayJSON)
        let client = makeTestClient()
        let issues = try await client.listIssues(project: "mygroup/my-project")
        XCTAssertEqual(issues.count, 1)
        let i = issues[0]
        XCTAssertEqual(i.iid, 1)
        XCTAssertEqual(i.title, "Fix the bug")
        XCTAssertEqual(i.state, "opened")
        XCTAssertEqual(i.labels, ["bug", "high"])
        XCTAssertEqual(i.milestone?.title, "v1.0")
        XCTAssertEqual(i.assignees.count, 1)
        XCTAssertEqual(i.assignees[0].username, "asmith")
        XCTAssertEqual(i.weight, 5)
        XCTAssertEqual(i.dueDate, "2024-02-01")
    }

    func testListIssuesQueryParams() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issuesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listIssues(
            project: "p", state: "opened", milestone: "v1.0",
            labels: "bug", assignee: "jdoe", search: "crash",
            page: 2, perPage: 5
        )
        let q = capturedURL?.query ?? ""
        XCTAssertTrue(q.contains("state=opened"))
        XCTAssertTrue(q.contains("milestone=v1.0"))
        XCTAssertTrue(q.contains("labels=bug"))
        XCTAssertTrue(q.contains("assignee_username=jdoe"))
        XCTAssertTrue(q.contains("search=crash"))
        XCTAssertTrue(q.contains("page=2"))
        XCTAssertTrue(q.contains("per_page=5"))
    }

    func testGetIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        let client = makeTestClient()
        let issue = try await client.getIssue(project: "mygroup/my-project", iid: 1)
        XCTAssertEqual(issue.iid, 1)
        XCTAssertEqual(issue.projectId, 42)
        XCTAssertEqual(issue.userNotesCount, 3)
    }

    func testCreateIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateIssueParams(
            title: "Fix the bug",
            description: "Something is broken",
            milestoneId: 10,
            labels: "bug,high",
            dueDate: "2024-02-01",
            weight: 5
        )
        let issue = try await client.createIssue(project: "mygroup/my-project", params: params)
        XCTAssertEqual(issue.title, "Fix the bug")
        // Verify body was sent
        XCTAssertEqual(capturedBody?["title"] as? String, "Fix the bug")
        XCTAssertEqual(capturedBody?["milestone_id"] as? Int, 10)
        XCTAssertEqual(capturedBody?["weight"] as? Int, 5)
        // nil fields should not appear
        XCTAssertNil(capturedBody?["assignee_ids"])
    }

    func testUpdateIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateIssueParams(title: "Updated title")
        _ = try await client.updateIssue(project: "mygroup/my-project", iid: 1, params: params)
        XCTAssertEqual(capturedMethod, "PUT")
    }

    func testCloseIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.closeIssue(project: "mygroup/my-project", iid: 1)
        XCTAssertEqual(capturedBody?["state_event"] as? String, "close")
    }

    func testReopenIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.reopenIssue(project: "mygroup/my-project", iid: 1)
        XCTAssertEqual(capturedBody?["state_event"] as? String, "reopen")
    }

    func testDeleteIssue() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteIssue(project: "mygroup/my-project", iid: 1)
        XCTAssertEqual(capturedMethod, "DELETE")
    }

    func testMoveIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.moveIssue(project: "mygroup/my-project", iid: 1, toProjectId: 99)
        XCTAssertEqual(capturedBody?["to_project_id"] as? Int, 99)
    }

    func testSubscribeToIssue() async throws {
        stubRaw(json: Fixtures.issueJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.issueJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.subscribeToIssue(project: "mygroup/my-project", iid: 1)
        XCTAssertTrue(capturedURL?.path.contains("subscribe") == true)
    }

    func testTimeEstimate() async throws {
        let statsJSON = """
        {"time_estimate":3600,"total_time_spent":0,"human_time_estimate":"1h","human_total_time_spent":null}
        """
        stubRaw(json: statsJSON)
        let client = makeTestClient()
        let stats = try await client.setIssueTimeEstimate(project: "p", iid: 1, duration: "1h")
        XCTAssertEqual(stats.timeEstimate, 3600)
        XCTAssertEqual(stats.humanTimeEstimate, "1h")
    }

    func testIssueNotesList() async throws {
        stubRaw(json: Fixtures.notesArrayJSON)
        let client = makeTestClient()
        let notes = try await client.listIssueNotes(project: "mygroup/my-project", issueIid: 1)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].body, "This is a comment")
    }

    func testIssueNoteCreate() async throws {
        stubRaw(json: Fixtures.noteJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.noteJSON.utf8))
        }
        let client = makeTestClient()
        let note = try await client.createIssueNote(project: "p", issueIid: 1, body: "Hello world")
        XCTAssertEqual(note.body, "This is a comment")
        XCTAssertEqual(capturedBody?["body"] as? String, "Hello world")
    }

    func testIssueNoteUpdate() async throws {
        stubRaw(json: Fixtures.noteJSON)
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.noteJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.updateIssueNote(project: "p", issueIid: 1, noteId: 55, body: "Updated")
        XCTAssertEqual(capturedMethod, "PUT")
    }

    func testIssueNoteDelete() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteIssueNote(project: "p", issueIid: 1, noteId: 55)
        XCTAssertEqual(capturedMethod, "DELETE")
    }
}
