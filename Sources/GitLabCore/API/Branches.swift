import Foundation

extension GitLabAPIClient {

    /// List branches in a project.
    public func listBranches(project: String, search: String? = nil, page: Int = 1, perPage: Int = 20) async throws -> [GLBranch] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = search { items.append(.init(name: "search", value: s)) }
        return try await get(path: "projects/\(Self.encodePath(project))/repository/branches", queryItems: items)
    }

    /// Get a single branch by name.
    public func getBranch(project: String, branch: String) async throws -> GLBranch {
        try await get(path: "projects/\(Self.encodePath(project))/repository/branches/\(Self.encodePath(branch))")
    }

    /// Create a branch from a ref (branch name, tag or commit SHA).
    public func createBranch(project: String, params: CreateBranchParams) async throws -> GLBranch {
        try await post(path: "projects/\(Self.encodePath(project))/repository/branches", body: params)
    }

    /// Delete a branch.
    public func deleteBranch(project: String, branch: String) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/repository/branches/\(Self.encodePath(branch))")
    }

    /// Delete all merged branches (protected ones are kept).
    public func deleteMergedBranches(project: String) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/repository/merged_branches")
    }
}
