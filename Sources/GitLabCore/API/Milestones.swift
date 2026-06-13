import Foundation

extension GitLabAPIClient {

    // MARK: Project milestones

    /// List milestones in a project.
    public func listMilestones(
        project: String,
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
        return try await get(path: "projects/\(Self.encodePath(project))/milestones", queryItems: items)
    }

    /// Get a single project milestone by its ID.
    public func getMilestone(project: String, milestoneId: Int) async throws -> GLMilestone {
        try await get(path: "projects/\(Self.encodePath(project))/milestones/\(milestoneId)")
    }

    /// Create a new project milestone.
    public func createMilestone(project: String, params: CreateMilestoneParams) async throws -> GLMilestone {
        try await post(path: "projects/\(Self.encodePath(project))/milestones", body: params)
    }

    /// Update a project milestone.
    public func updateMilestone(project: String, milestoneId: Int, params: UpdateMilestoneParams) async throws -> GLMilestone {
        try await put(path: "projects/\(Self.encodePath(project))/milestones/\(milestoneId)", body: params)
    }

    /// Delete a project milestone.
    public func deleteMilestone(project: String, milestoneId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/milestones/\(milestoneId)")
    }

    /// List issues assigned to a project milestone.
    public func listMilestoneIssues(project: String, milestoneId: Int, page: Int = 1, perPage: Int = 20) async throws -> [GLIssue] {
        try await get(
            path: "projects/\(Self.encodePath(project))/milestones/\(milestoneId)/issues",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// List merge requests assigned to a project milestone.
    public func listMilestoneMRs(project: String, milestoneId: Int, page: Int = 1, perPage: Int = 20) async throws -> [GLMergeRequest] {
        try await get(
            path: "projects/\(Self.encodePath(project))/milestones/\(milestoneId)/merge_requests",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }
}
