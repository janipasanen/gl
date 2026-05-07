import Foundation

extension GitLabAPIClient {

    /// List releases for a project.
    public func listReleases(project: String, page: Int = 1, perPage: Int = 20) async throws -> [GLRelease] {
        try await get(
            path: "projects/\(Self.encodePath(project))/releases",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Get a single release by tag name.
    public func getRelease(project: String, tagName: String) async throws -> GLRelease {
        try await get(path: "projects/\(Self.encodePath(project))/releases/\(Self.encodePath(tagName))")
    }

    /// Create a release.
    public func createRelease(project: String, params: CreateReleaseParams) async throws -> GLRelease {
        try await post(path: "projects/\(Self.encodePath(project))/releases", body: params)
    }

    /// Update a release.
    public func updateRelease(project: String, tagName: String, name: String, description: String? = nil) async throws -> GLRelease {
        struct Body: Encodable {
            var name: String
            var description: String?
            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(name, forKey: .name)
                try c.encodeIfPresent(description, forKey: .description)
            }
            enum CodingKeys: String, CodingKey { case name, description }
        }
        return try await put(
            path: "projects/\(Self.encodePath(project))/releases/\(Self.encodePath(tagName))",
            body: Body(name: name, description: description)
        )
    }

    /// Delete a release (the tag is kept).
    public func deleteRelease(project: String, tagName: String) async throws -> GLRelease {
        // DELETE returns the deleted release object
        let (data, response) = try await request(
            path: "projects/\(Self.encodePath(project))/releases/\(Self.encodePath(tagName))",
            method: "DELETE"
        )
        try checkResponse(response, data: data)
        return try Self.decode(data)
    }
}
