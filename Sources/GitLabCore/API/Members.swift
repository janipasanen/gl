import Foundation

extension GitLabAPIClient {

    // MARK: Project members

    /// List members of a project.
    public func listProjectMembers(project: String, query: String? = nil, page: Int = 1, perPage: Int = 50) async throws -> [GLMember] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let q = query { items.append(.init(name: "query", value: q)) }
        return try await get(path: "projects/\(Self.encodePath(project))/members", queryItems: items)
    }

    /// Get a single project member by user ID.
    public func getProjectMember(project: String, userId: Int) async throws -> GLMember {
        try await get(path: "projects/\(Self.encodePath(project))/members/\(userId)")
    }

    /// Add a member to a project.
    public func addProjectMember(project: String, params: AddMemberParams) async throws -> GLMember {
        try await post(path: "projects/\(Self.encodePath(project))/members", body: params)
    }

    /// Update a project member's access level.
    public func updateProjectMember(project: String, userId: Int, accessLevel: Int) async throws -> GLMember {
        struct Body: Encodable { let accessLevel: Int }
        return try await put(
            path: "projects/\(Self.encodePath(project))/members/\(userId)",
            body: Body(accessLevel: accessLevel)
        )
    }

    /// Remove a member from a project.
    public func removeProjectMember(project: String, userId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/members/\(userId)")
    }

    // MARK: Group members

    /// List members of a group.
    public func listGroupMembers(group: String, query: String? = nil, page: Int = 1, perPage: Int = 50) async throws -> [GLMember] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let q = query { items.append(.init(name: "query", value: q)) }
        return try await get(path: "groups/\(Self.encodePath(group))/members", queryItems: items)
    }

    /// Add a member to a group.
    public func addGroupMember(group: String, params: AddMemberParams) async throws -> GLMember {
        try await post(path: "groups/\(Self.encodePath(group))/members", body: params)
    }

    /// Remove a member from a group.
    public func removeGroupMember(group: String, userId: Int) async throws {
        try await delete(path: "groups/\(Self.encodePath(group))/members/\(userId)")
    }
}
