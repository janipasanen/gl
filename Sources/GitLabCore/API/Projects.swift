import Foundation

extension GitLabAPIClient {

    /// Fetch a project by its path (e.g. `"group/project"`) or numeric ID.
    public func getProject(path: String) async throws -> GLProject {
        try await get(path: "projects/\(Self.encodePath(path))")
    }

    /// List projects accessible to the authenticated user.
    public func listProjects(
        search: String? = nil,
        membership: Bool = false,
        owned: Bool = false,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLProject] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = search { items.append(.init(name: "search", value: s)) }
        if membership    { items.append(.init(name: "membership", value: "true")) }
        if owned         { items.append(.init(name: "owned", value: "true")) }
        return try await get(path: "projects", queryItems: items)
    }

    /// Create a project.
    ///
    /// The one operation `gl` could not do, so tooling that needed it had to
    /// fall back to `glab repo create`. Over REST it is a plain POST.
    ///
    /// To create inside a group, resolve the group's numeric id first —
    /// `/projects` takes `namespace_id`, not a path. `createProject(name:inGroup:)`
    /// does that lookup for you.
    public func createProject(params: CreateProjectParams) async throws -> GLProject {
        try await post(path: "projects", body: params)
    }

    /// Create a project inside a group given by full path, e.g.
    /// `"zesec/utility-software"`. Passing nil creates it under the caller's
    /// own namespace.
    public func createProject(
        name: String,
        inGroup group: String? = nil,
        path: String? = nil,
        description: String? = nil,
        visibility: String = "private",
        defaultBranch: String? = nil,
        initializeWithReadme: Bool = false
    ) async throws -> GLProject {
        var namespaceId: Int?
        if let group, !group.isEmpty {
            namespaceId = try await getGroup(id: group).id
        }
        let params = CreateProjectParams(
            name: name,
            path: path,
            namespaceId: namespaceId,
            description: description,
            visibility: visibility,
            defaultBranch: defaultBranch,
            initializeWithReadme: initializeWithReadme
        )
        return try await createProject(params: params)
    }

    /// Delete a project. Irreversible on most instances.
    public func deleteProject(path: String) async throws {
        try await delete(path: "projects/\(Self.encodePath(path))")
    }

    /// List projects belonging to a group.
    public func listGroupProjects(
        group: String,
        search: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLProject] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = search { items.append(.init(name: "search", value: s)) }
        return try await get(path: "groups/\(Self.encodePath(group))/projects", queryItems: items)
    }
}
