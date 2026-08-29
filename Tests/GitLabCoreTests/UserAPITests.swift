import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class UserAPITests: XCTestCase {

    func testCurrentUser() async throws {
        stubRaw(json: Fixtures.userJSON)
        let client = makeTestClient()
        let user = try await client.currentUser()
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.username, "jdoe")
        XCTAssertEqual(user.name, "Jane Doe")
        XCTAssertEqual(user.state, "active")
        XCTAssertEqual(user.email, "jdoe@example.com")
    }

    func testSearchUsers() async throws {
        stubRaw(json: Fixtures.usersArrayJSON)
        let client = makeTestClient()
        let users = try await client.searchUsers(query: "doe")
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users[0].username, "jdoe")
    }

    func testSearchUsersRequestURL() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.usersArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.searchUsers(query: "doe", page: 2, perPage: 5)
        XCTAssertTrue(capturedURL?.query?.contains("search=doe") == true)
        XCTAssertTrue(capturedURL?.query?.contains("page=2") == true)
        XCTAssertTrue(capturedURL?.query?.contains("per_page=5") == true)
    }

    func testGetUser() async throws {
        stubRaw(json: Fixtures.userJSON)
        let client = makeTestClient()
        let user = try await client.getUser(id: 1)
        XCTAssertEqual(user.id, 1)
    }
}
