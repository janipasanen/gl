import Foundation

extension GitLabAPIClient {

    // MARK: List / Get

    /// List merge requests for a project.
    public func listMergeRequests(
        project: String,
        state: String? = nil,
        sourceBranch: String? = nil,
        targetBranch: String? = nil,
        milestone: String? = nil,
        labels: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLMergeRequest] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let v = state        { items.append(.init(name: "state", value: v)) }
        if let v = sourceBranch { items.append(.init(name: "source_branch", value: v)) }
        if let v = targetBranch { items.append(.init(name: "target_branch", value: v)) }
        if let v = milestone    { items.append(.init(name: "milestone", value: v)) }
        if let v = labels       { items.append(.init(name: "labels", value: v)) }
        return try await get(path: "projects/\(Self.encodePath(project))/merge_requests", queryItems: items)
    }

    /// Get a single merge request by its IID.
    public func getMergeRequest(project: String, iid: Int) async throws -> GLMergeRequest {
        try await get(path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)")
    }

    // MARK: Create / Update

    /// Create a merge request.
    public func createMergeRequest(project: String, params: CreateMRParams) async throws -> GLMergeRequest {
        try await post(path: "projects/\(Self.encodePath(project))/merge_requests", body: params)
    }

    /// Update a merge request.
    public func updateMergeRequest(project: String, iid: Int, params: UpdateMRParams) async throws -> GLMergeRequest {
        try await put(path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)", body: params)
    }

    /// Close a merge request.
    public func closeMergeRequest(project: String, iid: Int) async throws -> GLMergeRequest {
        try await updateMergeRequest(project: project, iid: iid, params: UpdateMRParams(stateEvent: "close"))
    }

    /// Reopen a merge request.
    public func reopenMergeRequest(project: String, iid: Int) async throws -> GLMergeRequest {
        try await updateMergeRequest(project: project, iid: iid, params: UpdateMRParams(stateEvent: "reopen"))
    }

    // MARK: Merge

    /// Accept / merge a merge request.
    public func mergeMR(project: String, iid: Int, params: MergeMRParams = MergeMRParams()) async throws -> GLMergeRequest {
        try await put(path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)/merge", body: params)
    }

    // MARK: Subscribe

    /// Subscribe to a merge request.
    public func subscribeToMR(project: String, iid: Int) async throws -> GLMergeRequest {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)/subscribe",
            body: Empty()
        )
    }

    /// Unsubscribe from a merge request.
    public func unsubscribeFromMR(project: String, iid: Int) async throws -> GLMergeRequest {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)/unsubscribe",
            body: Empty()
        )
    }

    // MARK: Approvals

    /// Approve a merge request.
    public func approveMR(project: String, iid: Int) async throws -> GLMergeRequest {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)/approve",
            body: Empty()
        )
    }

    /// Unapprove / revoke approval from a merge request.
    public func unapproveMR(project: String, iid: Int) async throws -> GLMergeRequest {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(iid)/unapprove",
            body: Empty()
        )
    }
}
