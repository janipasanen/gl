import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class GroupAPITests: XCTestCase {

    func testListGroups() async throws {
        stubRaw(json: Fixtures.groupsArrayJSON)
        let client = makeTestClient()
        let groups = try await client.listGroups()
        XCTAssertEqual(groups.count, 1)
        let g = groups[0]
        XCTAssertEqual(g.id, 5)
        XCTAssertEqual(g.fullPath, "mygroup")
        XCTAssertEqual(g.visibility, "private")
    }

    func testListGroupsWithSearch() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.groupsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listGroups(search: "my", owned: true)
        XCTAssertTrue(capturedQuery?.contains("search=my") == true)
        XCTAssertTrue(capturedQuery?.contains("owned=true") == true)
    }

    func testGetGroup() async throws {
        stubRaw(json: Fixtures.groupJSON)
        let client = makeTestClient()
        let g = try await client.getGroup(id: "mygroup")
        XCTAssertEqual(g.id, 5)
        XCTAssertEqual(g.name, "My Group")
    }

    func testListSubgroups() async throws {
        stubRaw(json: Fixtures.groupsArrayJSON)
        let client = makeTestClient()
        let groups = try await client.listSubgroups(group: "mygroup")
        XCTAssertEqual(groups.count, 1)
    }

    func testListGroupMembers() async throws {
        stubRaw(json: Fixtures.membersArrayJSON)
        let client = makeTestClient()
        let members = try await client.listGroupMembers(group: "mygroup")
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].username, "asmith")
    }

    func testAddGroupMember() async throws {
        stubRaw(status: 201, json: Fixtures.memberJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.memberJSON.utf8))
        }
        let client = makeTestClient()
        let params = AddMemberParams(userId: 2, accessLevel: 30)
        let m = try await client.addGroupMember(group: "mygroup", params: params)
        XCTAssertEqual(m.username, "asmith")
        XCTAssertEqual(capturedBody?["user_id"] as? Int, 2)
        XCTAssertEqual(capturedBody?["access_level"] as? Int, 30)
    }

    func testRemoveGroupMember() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.removeGroupMember(group: "mygroup", userId: 2)
        XCTAssertEqual(capturedMethod, "DELETE")
    }
}
