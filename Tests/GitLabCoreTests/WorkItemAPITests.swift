import XCTest
@testable import GitLabCore

final class WorkItemAPITests: XCTestCase {

    func testListWorkItems() async throws {
        stubRaw(json: Fixtures.workItemsArrayJSON)
        let client = makeTestClient()
        let items = try await client.listWorkItems(project: "mygroup/my-project")
        XCTAssertEqual(items.count, 1)
        let w = items[0]
        XCTAssertEqual(w.iid, 1)
        XCTAssertEqual(w.title, "My work item")
        XCTAssertEqual(w.state, "OPEN")
        XCTAssertEqual(w.workItemType?.name, "Issue")
    }

    func testGetWorkItem() async throws {
        stubRaw(json: Fixtures.workItemJSON)
        let client = makeTestClient()
        let w = try await client.getWorkItem(project: "p", iid: 1)
        XCTAssertEqual(w.iid, 1)
        XCTAssertEqual(w.title, "My work item")
    }

    func testCreateWorkItem() async throws {
        stubRaw(status: 201, json: Fixtures.workItemJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateWorkItemParams(
            title: "My work item",
            workItemTypeId: "gid://gitlab/WorkItems::Type/1",
            description: "Task description",
            assigneeIds: [2],
            milestoneId: 10,
            dueDate: "2024-06-01",
            startDate: "2024-05-01",
            weight: 3
        )
        let w = try await client.createWorkItem(project: "p", params: params)
        XCTAssertEqual(w.title, "My work item")
        XCTAssertEqual(capturedBody?["title"] as? String, "My work item")
        XCTAssertEqual(capturedBody?["work_item_type_id"] as? String, "gid://gitlab/WorkItems::Type/1")
        XCTAssertEqual(capturedBody?["description"] as? String, "Task description")
        XCTAssertEqual(capturedBody?["assignee_ids"] as? [Int], [2])
        XCTAssertEqual(capturedBody?["milestone_id"] as? Int, 10)
        XCTAssertEqual(capturedBody?["due_date"] as? String, "2024-06-01")
        XCTAssertEqual(capturedBody?["start_date"] as? String, "2024-05-01")
        XCTAssertEqual(capturedBody?["weight"] as? Int, 3)
    }

    func testUpdateWorkItem() async throws {
        stubRaw(json: Fixtures.workItemJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateWorkItemParams(
            title: "Updated work item",
            description: "Updated desc",
            stateEvent: "close",
            assigneeIds: [2, 3],
            milestoneId: 10,
            dueDate: "2024-06-01",
            startDate: "2024-05-01",
            weight: 8
        )
        _ = try await client.updateWorkItem(project: "p", iid: 1, params: params)
        XCTAssertEqual(capturedBody?["title"] as? String, "Updated work item")
        XCTAssertEqual(capturedBody?["description"] as? String, "Updated desc")
        XCTAssertEqual(capturedBody?["state_event"] as? String, "close")
        XCTAssertEqual(capturedBody?["assignee_ids"] as? [Int], [2, 3])
        XCTAssertEqual(capturedBody?["milestone_id"] as? Int, 10)
        XCTAssertEqual(capturedBody?["due_date"] as? String, "2024-06-01")
        XCTAssertEqual(capturedBody?["start_date"] as? String, "2024-05-01")
        XCTAssertEqual(capturedBody?["weight"] as? Int, 8)
    }

    func testListGroupWorkItems() async throws {
        stubRaw(json: Fixtures.workItemsArrayJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemsArrayJSON.utf8))
        }
        let client = makeTestClient()
        let items = try await client.listGroupWorkItems(group: "mygroup")
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(capturedURL?.path.contains("groups") == true)
    }
}
