import Foundation

extension GitLabAPIClient {

    // MARK: List / Get

    /// List issues for a project.
    public func listIssues(
        project: String,
        state: String? = nil,
        milestone: String? = nil,
        labels: String? = nil,
        assignee: String? = nil,
        search: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLIssue] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let v = state     { items.append(.init(name: "state", value: v)) }
        if let v = milestone { items.append(.init(name: "milestone", value: v)) }
        if let v = labels    { items.append(.init(name: "labels", value: v)) }
        if let v = assignee  { items.append(.init(name: "assignee_username", value: v)) }
        if let v = search    { items.append(.init(name: "search", value: v)) }
        return try await get(path: "projects/\(Self.encodePath(project))/issues", queryItems: items)
    }

    /// Get a single issue by its IID (project-scoped ID).
    public func getIssue(project: String, iid: Int) async throws -> GLIssue {
        try await get(path: "projects/\(Self.encodePath(project))/issues/\(iid)")
    }

    // MARK: Create / Update / Delete

    /// Create a new issue.
    public func createIssue(project: String, params: CreateIssueParams) async throws -> GLIssue {
        try await post(path: "projects/\(Self.encodePath(project))/issues", body: params)
    }

    /// Update an existing issue.
    public func updateIssue(project: String, iid: Int, params: UpdateIssueParams) async throws -> GLIssue {
        try await put(path: "projects/\(Self.encodePath(project))/issues/\(iid)", body: params)
    }

    /// Close an issue.
    public func closeIssue(project: String, iid: Int) async throws -> GLIssue {
        let params = UpdateIssueParams(stateEvent: "close")
        return try await updateIssue(project: project, iid: iid, params: params)
    }

    /// Reopen a closed issue.
    public func reopenIssue(project: String, iid: Int) async throws -> GLIssue {
        let params = UpdateIssueParams(stateEvent: "reopen")
        return try await updateIssue(project: project, iid: iid, params: params)
    }

    /// Delete an issue (requires admin / project owner).
    public func deleteIssue(project: String, iid: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/issues/\(iid)")
    }

    // MARK: Move / Subscribe

    /// Move an issue to another project.
    public func moveIssue(project: String, iid: Int, toProjectId: Int) async throws -> GLIssue {
        struct Body: Encodable { let toProjectId: Int }
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/move",
            body: Body(toProjectId: toProjectId)
        )
    }

    /// Subscribe to an issue (receive notifications).
    public func subscribeToIssue(project: String, iid: Int) async throws -> GLIssue {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/subscribe",
            body: Empty()
        )
    }

    /// Unsubscribe from an issue.
    public func unsubscribeFromIssue(project: String, iid: Int) async throws -> GLIssue {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/unsubscribe",
            body: Empty()
        )
    }

    // MARK: Time tracking

    /// Set a time estimate on an issue (e.g. "3h30m").
    public func setIssueTimeEstimate(project: String, iid: Int, duration: String) async throws -> GLTimeStats {
        struct Body: Encodable { let duration: String }
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/time_estimate",
            body: Body(duration: duration)
        )
    }

    /// Add time spent on an issue (e.g. "1h").
    public func addIssueTimeSpent(project: String, iid: Int, duration: String) async throws -> GLTimeStats {
        struct Body: Encodable { let duration: String }
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/add_spent_time",
            body: Body(duration: duration)
        )
    }

    /// Reset time tracking on an issue.
    public func resetIssueTimeSpent(project: String, iid: Int) async throws -> GLTimeStats {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(iid)/reset_spent_time",
            body: Empty()
        )
    }
}
