import Foundation

extension GitLabAPIClient {

    /// List snippets in a project.
    public func listSnippets(project: String, page: Int = 1, perPage: Int = 20) async throws -> [GLSnippet] {
        try await get(
            path: "projects/\(Self.encodePath(project))/snippets",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Get a single project snippet by its ID.
    public func getSnippet(project: String, snippetId: Int) async throws -> GLSnippet {
        try await get(path: "projects/\(Self.encodePath(project))/snippets/\(snippetId)")
    }

    /// Create a snippet in a project.
    public func createSnippet(project: String, params: CreateSnippetParams) async throws -> GLSnippet {
        try await post(path: "projects/\(Self.encodePath(project))/snippets", body: params)
    }

    /// Update a project snippet.
    public func updateSnippet(project: String, snippetId: Int, params: UpdateSnippetParams) async throws -> GLSnippet {
        try await put(path: "projects/\(Self.encodePath(project))/snippets/\(snippetId)", body: params)
    }

    /// Delete a project snippet.
    public func deleteSnippet(project: String, snippetId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/snippets/\(snippetId)")
    }
}
