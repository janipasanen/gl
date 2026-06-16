import XCTest
@testable import GitLabCore

/// Work items go through GitLab GraphQL (`/api/graphql`). These tests stub the
/// GraphQL response envelopes and assert on the queries/mutations sent.
final class WorkItemAPITests: XCTestCase {

    /// Decode the `query` string from a captured GraphQL request body.
    private func queryString(_ req: URLRequest) -> String {
        guard let body = req.httpBody,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return "" }
        return obj["query"] as? String ?? ""
    }

    private func inputVariables(_ req: URLRequest) -> [String: Any]? {
        guard let body = req.httpBody,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let vars = obj["variables"] as? [String: Any] else { return nil }
        return vars["input"] as? [String: Any]
    }

    func testListWorkItems() async throws {
        var capturedURL: URL?
        var capturedQuery = ""
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            capturedQuery = (try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any])?["query"] as? String ?? ""
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemsListEnvelope.utf8))
        }
        let client = makeTestClient()
        let items = try await client.listWorkItems(project: "mygroup/my-project", first: 20, state: "open")
        XCTAssertEqual(items.count, 1)
        let w = items[0]
        XCTAssertEqual(w.iid, "1")
        XCTAssertEqual(w.id, "gid://gitlab/WorkItem/123")
        XCTAssertEqual(w.title, "My work item")
        XCTAssertEqual(w.state, "opened")
        XCTAssertEqual(w.workItemType?.name, "Issue")
        XCTAssertEqual(capturedURL?.absoluteString, "https://gitlab.example.com/api/graphql")
        XCTAssertTrue(capturedQuery.contains("workItems(first: $first"))
    }

    func testGetWorkItem() async throws {
        var capturedQuery = ""
        MockURLProtocol.requestHandler = { req in
            capturedQuery = (try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any])?["query"] as? String ?? ""
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemGetEnvelope.utf8))
        }
        let client = makeTestClient()
        let w = try await client.getWorkItem(project: "p", iid: "1")
        XCTAssertEqual(w.iid, "1")
        XCTAssertEqual(w.title, "My work item")
        XCTAssertTrue(capturedQuery.contains("workItems(iid: $iid)"))
    }

    func testListWorkItemTypes() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemTypesEnvelope.utf8))
        }
        let client = makeTestClient()
        let types = try await client.listWorkItemTypes(project: "p")
        XCTAssertEqual(types.count, 2)
        XCTAssertEqual(types[0].name, "Issue")
        XCTAssertEqual(types[1].id, "gid://gitlab/WorkItems::Type/5")
    }

    func testResolveWorkItemTypeId() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemTypesEnvelope.utf8))
        }
        let client = makeTestClient()
        let id = try await client.resolveWorkItemTypeId(project: "p", name: "task")  // case-insensitive
        XCTAssertEqual(id, "gid://gitlab/WorkItems::Type/5")
    }

    func testCreateWorkItem() async throws {
        var capturedInput: [String: Any]?
        var capturedQuery = ""
        MockURLProtocol.requestHandler = { req in
            let obj = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            capturedQuery = obj?["query"] as? String ?? ""
            capturedInput = (obj?["variables"] as? [String: Any])?["input"] as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.workItemCreateEnvelope.utf8))
        }
        let client = makeTestClient()
        let params = CreateWorkItemParams(
            title: "My work item",
            workItemTypeId: "gid://gitlab/WorkItems::Type/1",
            description: "Task description"
        )
        let w = try await client.createWorkItem(project: "mygroup/my-project", params: params)
        XCTAssertEqual(w.title, "My work item")
        XCTAssertTrue(capturedQuery.contains("workItemCreate(input: $input)"))
        XCTAssertEqual(capturedInput?["namespacePath"] as? String, "mygroup/my-project")
        XCTAssertEqual(capturedInput?["title"] as? String, "My work item")
        XCTAssertEqual(capturedInput?["workItemTypeId"] as? String, "gid://gitlab/WorkItems::Type/1")
        XCTAssertEqual((capturedInput?["descriptionWidget"] as? [String: Any])?["description"] as? String, "Task description")
    }

    func testCreateWorkItemSurfacesMutationErrors() async {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{"workItemCreate":{"workItem":null,"errors":["Title can't be blank"]}}}"#.utf8))
        }
        let client = makeTestClient()
        do {
            _ = try await client.createWorkItem(project: "p", params: CreateWorkItemParams(title: "", workItemTypeId: "gid://gitlab/WorkItems::Type/1"))
            XCTFail("expected mutation errors to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Title can't be blank"))
        }
    }

    func testCloseWorkItemResolvesGidThenMutates() async throws {
        var sawUpdateWithGid = false
        MockURLProtocol.requestHandler = { req in
            let obj = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let query = obj?["query"] as? String ?? ""
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if query.contains("workItemUpdate") {
                let input = (obj?["variables"] as? [String: Any])?["input"] as? [String: Any]
                if (input?["id"] as? String) == "gid://gitlab/WorkItem/123",
                   (input?["stateEvent"] as? String) == "CLOSE" {
                    sawUpdateWithGid = true
                }
                return (r, Data(Fixtures.workItemUpdateEnvelope.utf8))
            }
            // First call: iid -> gid resolution
            return (r, Data(Fixtures.workItemGetEnvelope.utf8))
        }
        let client = makeTestClient()
        _ = try await client.closeWorkItem(project: "p", iid: "1")
        XCTAssertTrue(sawUpdateWithGid, "close should resolve the iid to a global id and send stateEvent CLOSE")
    }

    func testDeleteWorkItemResolvesGidThenMutates() async throws {
        var sawDeleteWithGid = false
        MockURLProtocol.requestHandler = { req in
            let obj = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let query = obj?["query"] as? String ?? ""
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if query.contains("workItemDelete") {
                let input = (obj?["variables"] as? [String: Any])?["input"] as? [String: Any]
                if (input?["id"] as? String) == "gid://gitlab/WorkItem/123" { sawDeleteWithGid = true }
                return (r, Data(Fixtures.workItemDeleteEnvelope.utf8))
            }
            return (r, Data(Fixtures.workItemGetEnvelope.utf8))
        }
        let client = makeTestClient()
        try await client.deleteWorkItem(project: "p", iid: "1")
        XCTAssertTrue(sawDeleteWithGid)
    }

    func testListGroupWorkItems() async throws {
        var capturedQuery = ""
        MockURLProtocol.requestHandler = { req in
            capturedQuery = (try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any])?["query"] as? String ?? ""
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(#"{"data":{"group":{"workItems":{"nodes":[\#(Fixtures.workItemJSON)]}}}}"#.utf8))
        }
        let client = makeTestClient()
        let items = try await client.listGroupWorkItems(group: "mygroup")
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(capturedQuery.contains("group(fullPath: $p)"))
    }
}
