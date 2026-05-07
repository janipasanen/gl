import Foundation

extension GitLabAPIClient {

    /// List tags for a project.
    public func listTags(project: String, search: String? = nil, page: Int = 1, perPage: Int = 20) async throws -> [GLTag] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = search { items.append(.init(name: "search", value: s)) }
        return try await get(path: "projects/\(Self.encodePath(project))/repository/tags", queryItems: items)
    }

    /// Get a single tag by name.
    public func getTag(project: String, tagName: String) async throws -> GLTag {
        try await get(path: "projects/\(Self.encodePath(project))/repository/tags/\(Self.encodePath(tagName))")
    }

    /// Create a tag.
    public func createTag(project: String, params: CreateTagParams) async throws -> GLTag {
        try await post(path: "projects/\(Self.encodePath(project))/repository/tags", body: params)
    }

    /// Delete a tag.
    public func deleteTag(project: String, tagName: String) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/repository/tags/\(Self.encodePath(tagName))")
    }
}
