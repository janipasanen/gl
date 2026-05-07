import XCTest
@testable import GitLabCore

final class ProjectAPITests: XCTestCase {

    func testGetProject() async throws {
        stubRaw(json: Fixtures.projectJSON)
        let client = makeTestClient()
        let project = try await client.getProject(path: "mygroup/my-project")
        XCTAssertEqual(project.id, 42)
        XCTAssertEqual(project.name, "My Project")
        XCTAssertEqual(project.pathWithNamespace, "mygroup/my-project")
        XCTAssertEqual(project.visibility, "private")
        XCTAssertEqual(project.starCount, 3)
        XCTAssertEqual(project.openIssuesCount, 5)
    }

    func testGetProjectURLEncoding() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.projectJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.getProject(path: "group/sub/project")
        XCTAssertTrue(capturedURL?.absoluteString.contains("group%2Fsub%2Fproject") == true)
    }

    func testListProjects() async throws {
        stubRaw(json: Fixtures.projectsArrayJSON)
        let client = makeTestClient()
        let projects = try await client.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].id, 42)
    }

    func testListProjectsQueryParams() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.projectsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listProjects(search: "test", membership: true, owned: false, page: 2, perPage: 10)
        let query = capturedURL?.query ?? ""
        XCTAssertTrue(query.contains("search=test"))
        XCTAssertTrue(query.contains("membership=true"))
        XCTAssertTrue(query.contains("page=2"))
        XCTAssertTrue(query.contains("per_page=10"))
    }

    func testListGroupProjects() async throws {
        stubRaw(json: Fixtures.projectsArrayJSON)
        let client = makeTestClient()
        let projects = try await client.listGroupProjects(group: "mygroup")
        XCTAssertEqual(projects.count, 1)
    }
}
