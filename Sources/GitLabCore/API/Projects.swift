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
