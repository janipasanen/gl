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
        let params = CreateWorkItemParams(title: "My work item", workItemTypeId: "gid://gitlab/WorkItems::Type/1")
        let w = try await client.createWorkItem(project: "p", params: params)
        XCTAssertEqual(w.title, "My work item")
        XCTAssertEqual(capturedBody?["title"] as? String, "My work item")
        XCTAssertEqual(capturedBody?["work_item_type_id"] as? String, "gid://gitlab/WorkItems::Type/1")
        XCTAssertNil(capturedBody?["description"])
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
