import Foundation

extension GitLabAPIClient {

    /// List work items for a project (GitLab 15.7+).
    public func listWorkItems(project: String, page: Int = 1, perPage: Int = 20) async throws -> [GLWorkItem] {
        let items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        return try await get(path: "projects/\(Self.encodePath(project))/work_items", queryItems: items)
    }

    /// Get a single work item by IID.
    public func getWorkItem(project: String, iid: Int) async throws -> GLWorkItem {
        try await get(path: "projects/\(Self.encodePath(project))/work_items/\(iid)")
    }

    /// Create a work item in a project.
    public func createWorkItem(project: String, params: CreateWorkItemParams) async throws -> GLWorkItem {
        try await post(path: "projects/\(Self.encodePath(project))/work_items", body: params)
    }

    /// Update a work item.
    public func updateWorkItem(project: String, iid: Int, params: UpdateWorkItemParams) async throws -> GLWorkItem {
        try await put(path: "projects/\(Self.encodePath(project))/work_items/\(iid)", body: params)
    }

    /// Close a work item.
    public func closeWorkItem(project: String, iid: Int) async throws -> GLWorkItem {
        try await updateWorkItem(project: project, iid: iid, params: UpdateWorkItemParams(stateEvent: "close"))
    }

    /// Reopen a work item.
    public func reopenWorkItem(project: String, iid: Int) async throws -> GLWorkItem {
        try await updateWorkItem(project: project, iid: iid, params: UpdateWorkItemParams(stateEvent: "reopen"))
    }

    /// Delete a work item.
    public func deleteWorkItem(project: String, iid: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/work_items/\(iid)")
    }

    /// List work items for a group (GitLab 15.7+).
    public func listGroupWorkItems(group: String, page: Int = 1, perPage: Int = 20) async throws -> [GLWorkItem] {
        let items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        return try await get(path: "groups/\(Self.encodePath(group))/work_items", queryItems: items)
    }
}
