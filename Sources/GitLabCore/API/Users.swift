import Foundation

extension GitLabAPIClient {

    /// Returns the authenticated user.
    public func currentUser() async throws -> GLUser {
        try await get(path: "user")
    }

    /// Search for users by username / name fragment.
    public func searchUsers(query: String, page: Int = 1, perPage: Int = 20) async throws -> [GLUser] {
        try await get(path: "users", queryItems: [
            .init(name: "search", value: query),
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ])
    }

    /// Fetch a single user by numeric ID.
    public func getUser(id: Int) async throws -> GLUser {
        try await get(path: "users/\(id)")
    }
}
