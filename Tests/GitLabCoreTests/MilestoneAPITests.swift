import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MilestoneAPITests: XCTestCase {

    func testListMilestones() async throws {
        stubRaw(json: Fixtures.milestonesArrayJSON)
        let client = makeTestClient()
        let milestones = try await client.listMilestones(project: "mygroup/my-project")
        XCTAssertEqual(milestones.count, 1)
        let m = milestones[0]
        XCTAssertEqual(m.id, 10)
        XCTAssertEqual(m.title, "v1.0")
        XCTAssertEqual(m.state, "active")
        XCTAssertEqual(m.dueDate, "2024-03-31")
    }

    func testListMilestonesStateFilter() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestonesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listMilestones(project: "p", state: "closed")
        XCTAssertTrue(capturedQuery?.contains("state=closed") == true)
    }

    func testListMilestonesExtraFilters() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestonesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listMilestones(
            project: "p",
            title: "v1.0",
            search: "release",
            iids: [1, 2],
            updatedBefore: "2024-01-01T00:00:00Z",
            updatedAfter: "2023-01-01T00:00:00Z"
        )
        XCTAssertTrue(capturedQuery?.contains("title=v1.0") == true)
        XCTAssertTrue(capturedQuery?.contains("search=release") == true)
        XCTAssertTrue(capturedQuery?.contains("iids%5B%5D=1") == true || capturedQuery?.contains("iids[]=1") == true)
        XCTAssertTrue(capturedQuery?.contains("updated_before=2024-01-01T00:00:00Z") == true)
        XCTAssertTrue(capturedQuery?.contains("updated_after=2023-01-01T00:00:00Z") == true)
    }

    func testGetMilestone() async throws {
        stubRaw(json: Fixtures.milestoneJSON)
        let client = makeTestClient()
        let m = try await client.getMilestone(project: "mygroup/my-project", milestoneId: 10)
        XCTAssertEqual(m.id, 10)
        XCTAssertEqual(m.iid, 1)
    }

    func testCreateMilestone() async throws {
        stubRaw(status: 201, json: Fixtures.milestoneJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestoneJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateMilestoneParams(title: "v1.0", description: "First release", dueDate: "2024-03-31", startDate: "2024-01-01")
        let m = try await client.createMilestone(project: "mygroup/my-project", params: params)
        XCTAssertEqual(m.title, "v1.0")
        XCTAssertEqual(capturedBody?["title"] as? String, "v1.0")
        XCTAssertEqual(capturedBody?["due_date"] as? String, "2024-03-31")
        XCTAssertNil(capturedBody?["state_event"])
    }

    func testUpdateMilestone() async throws {
        stubRaw(json: Fixtures.milestoneJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestoneJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateMilestoneParams(stateEvent: "close")
        _ = try await client.updateMilestone(project: "p", milestoneId: 10, params: params)
        XCTAssertEqual(capturedBody?["state_event"] as? String, "close")
        XCTAssertNil(capturedBody?["title"])
    }

    func testDeleteMilestone() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteMilestone(project: "p", milestoneId: 10)
        XCTAssertEqual(capturedMethod, "DELETE")
    }

    func testListMilestoneIssues() async throws {
        stubRaw(json: Fixtures.issuesArrayJSON)
        let client = makeTestClient()
        let issues = try await client.listMilestoneIssues(project: "p", milestoneId: 10)
        XCTAssertEqual(issues.count, 1)
    }

    func testListMilestoneMRs() async throws {
        stubRaw(json: Fixtures.mrsArrayJSON)
        let client = makeTestClient()
        let mrs = try await client.listMilestoneMRs(project: "p", milestoneId: 10)
        XCTAssertEqual(mrs.count, 1)
    }

    // MARK: - Group milestones

    func testListGroupMilestones() async throws {
        stubRaw(json: Fixtures.milestonesArrayJSON)
        let client = makeTestClient()
        let ms = try await client.listGroupMilestones(group: "mygroup")
        XCTAssertEqual(ms.count, 1)
    }

    func testListGroupMilestonesFilters() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestonesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listGroupMilestones(group: "mygroup", state: "active", title: "v1.0", search: "release", iids: [1])
        XCTAssertTrue(capturedQuery?.contains("state=active") == true)
        XCTAssertTrue(capturedQuery?.contains("title=v1.0") == true)
        XCTAssertTrue(capturedQuery?.contains("search=release") == true)
        XCTAssertTrue(capturedQuery?.contains("iids%5B%5D=1") == true || capturedQuery?.contains("iids[]=1") == true)
    }

    func testCreateGroupMilestone() async throws {
        stubRaw(status: 201, json: Fixtures.milestoneJSON)
        let client = makeTestClient()
        let params = CreateMilestoneParams(title: "v1.0")
        let m = try await client.createGroupMilestone(group: "mygroup", params: params)
        XCTAssertEqual(m.title, "v1.0")
    }

    func testUpdateGroupMilestone() async throws {
        stubRaw(json: Fixtures.milestoneJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.milestoneJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.updateGroupMilestone(group: "mygroup", milestoneId: 10, params: UpdateMilestoneParams())
        XCTAssertTrue(capturedURL?.path.contains("groups") == true)
    }

    func testDeleteGroupMilestone() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteGroupMilestone(group: "mygroup", milestoneId: 10)
        XCTAssertTrue(capturedURL?.path.contains("milestones/10") == true)
    }
}
