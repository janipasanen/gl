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

    // MARK: - Create

    func testCreateProjectPostsToProjects() async throws {
        var captured: (url: URL?, method: String?, body: Data?)
        MockURLProtocol.requestHandler = { req in
            captured = (req.url, req.httpMethod, req.httpBodyStream.map { stream in
                stream.open(); defer { stream.close() }
                var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                return data
            } ?? req.httpBody)
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.projectJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateProjectParams(name: "My Project", path: "my-project", namespaceId: 7)
        let project = try await client.createProject(params: params)

        XCTAssertEqual(project.id, 42)
        XCTAssertEqual(captured.method, "POST")
        XCTAssertTrue(captured.url?.absoluteString.hasSuffix("/projects") == true,
                      "should POST to /projects, got \(captured.url?.absoluteString ?? "nil")")

        let body = try XCTUnwrap(captured.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "My Project")
        XCTAssertEqual(json["path"] as? String, "my-project")
        // The endpoint takes a numeric namespace_id, not a group path.
        XCTAssertEqual(json["namespace_id"] as? Int, 7)
        XCTAssertEqual(json["visibility"] as? String, "private")
    }

    func testCreateProjectOmitsDefaultBranchWithoutReadme() throws {
        // GitLab rejects default_branch on an empty repo, so it is only sent
        // alongside initialize_with_readme.
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let bare = CreateProjectParams(name: "x", defaultBranch: "development")
        let bareJSON = try JSONSerialization.jsonObject(with: encoder.encode(bare)) as? [String: Any]
        XCTAssertNil(bareJSON?["default_branch"], "default_branch must be omitted without a README")
        XCTAssertNil(bareJSON?["initialize_with_readme"])

        let seeded = CreateProjectParams(name: "x", defaultBranch: "development", initializeWithReadme: true)
        let seededJSON = try JSONSerialization.jsonObject(with: encoder.encode(seeded)) as? [String: Any]
        XCTAssertEqual(seededJSON?["default_branch"] as? String, "development")
        XCTAssertEqual(seededJSON?["initialize_with_readme"] as? Bool, true)
    }

    func testCreateProjectInGroupResolvesNamespaceId() async throws {
        // Two calls: GET the group to resolve its id, then POST the project.
        var paths: [String] = []
        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            paths.append(url.path)
            let r = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.contains("/groups/") {
                return (r, Data(Fixtures.groupJSON.utf8))
            }
            return (r, Data(Fixtures.projectJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.createProject(name: "My Project", inGroup: "zesec/utility-software")

        XCTAssertEqual(paths.count, 2, "expected a group lookup then a create, got \(paths)")
        XCTAssertTrue(paths[0].contains("groups"), "first call should resolve the group, got \(paths[0])")
        XCTAssertTrue(paths[1].hasSuffix("/projects"), "second call should create, got \(paths[1])")
    }

    func testDeleteProject() async throws {
        var method: String?
        MockURLProtocol.requestHandler = { req in
            method = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteProject(path: "group/proj")
        XCTAssertEqual(method, "DELETE")
    }

}
