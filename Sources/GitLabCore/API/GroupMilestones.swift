import Foundation

extension GitLabAPIClient {

    // MARK: Group milestones

    /// List milestones in a group.
    public func listGroupMilestones(
        group: String,
        state: String? = nil,
        title: String? = nil,
        search: String? = nil,
        iids: [Int]? = nil,
        updatedBefore: String? = nil,
        updatedAfter: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLMilestone] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let s = state { items.append(.init(name: "state", value: s)) }
        if let t = title { items.append(.init(name: "title", value: t)) }
        if let q = search { items.append(.init(name: "search", value: q)) }
        if let list = iids {
            for iid in list {
                items.append(.init(name: "iids[]", value: "\(iid)"))
            }
        }
        if let v = updatedBefore { items.append(.init(name: "updated_before", value: v)) }
        if let v = updatedAfter { items.append(.init(name: "updated_after", value: v)) }
        return try await get(path: "groups/\(Self.encodePath(group))/milestones", queryItems: items)
    }

    /// Get a single group milestone by ID.
    public func getGroupMilestone(group: String, milestoneId: Int) async throws -> GLMilestone {
        try await get(path: "groups/\(Self.encodePath(group))/milestones/\(milestoneId)")
    }

    /// Create a milestone in a group.
    public func createGroupMilestone(group: String, params: CreateMilestoneParams) async throws -> GLMilestone {
        try await post(path: "groups/\(Self.encodePath(group))/milestones", body: params)
    }

    /// Update a group milestone.
    public func updateGroupMilestone(group: String, milestoneId: Int, params: UpdateMilestoneParams) async throws -> GLMilestone {
        try await put(path: "groups/\(Self.encodePath(group))/milestones/\(milestoneId)", body: params)
    }

    /// Delete a group milestone.
    public func deleteGroupMilestone(group: String, milestoneId: Int) async throws {
        try await delete(path: "groups/\(Self.encodePath(group))/milestones/\(milestoneId)")
    }

    /// List issues belonging to a group milestone.
    public func listGroupMilestoneIssues(group: String, milestoneId: Int, page: Int = 1, perPage: Int = 20) async throws -> [GLIssue] {
        try await get(
            path: "groups/\(Self.encodePath(group))/milestones/\(milestoneId)/issues",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }
}
