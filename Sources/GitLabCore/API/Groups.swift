import Foundation

extension GitLabAPIClient {

    /// List groups accessible to the authenticated user.
    public func listGroups(
        search: String? = nil,
        owned: Bool = false,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLGroup] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = search { items.append(.init(name: "search", value: s)) }
        if owned          { items.append(.init(name: "owned", value: "true")) }
        return try await get(path: "groups", queryItems: items)
    }

    /// Get a group by path or numeric ID.
    public func getGroup(id: String) async throws -> GLGroup {
        try await get(path: "groups/\(Self.encodePath(id))")
    }

    /// List subgroups of a group.
    public func listSubgroups(group: String, page: Int = 1, perPage: Int = 20) async throws -> [GLGroup] {
        try await get(
            path: "groups/\(Self.encodePath(group))/subgroups",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }
}
