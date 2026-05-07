import Foundation

extension GitLabAPIClient {

    /// List labels for a project.
    public func listLabels(project: String, page: Int = 1, perPage: Int = 50) async throws -> [GLLabel] {
        try await get(
            path: "projects/\(Self.encodePath(project))/labels",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Get a single label by its ID.
    public func getLabel(project: String, labelId: Int) async throws -> GLLabel {
        try await get(path: "projects/\(Self.encodePath(project))/labels/\(labelId)")
    }

    /// Create a label in a project.
    public func createLabel(project: String, params: CreateLabelParams) async throws -> GLLabel {
        try await post(path: "projects/\(Self.encodePath(project))/labels", body: params)
    }

    /// Update a label.
    public func updateLabel(project: String, labelId: Int, params: UpdateLabelParams) async throws -> GLLabel {
        try await put(path: "projects/\(Self.encodePath(project))/labels/\(labelId)", body: params)
    }

    /// Delete a label.
    public func deleteLabel(project: String, labelId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/labels/\(labelId)")
    }

    // MARK: Group labels

    /// List labels in a group.
    public func listGroupLabels(group: String, page: Int = 1, perPage: Int = 50) async throws -> [GLLabel] {
        try await get(
            path: "groups/\(Self.encodePath(group))/labels",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Create a label in a group.
    public func createGroupLabel(group: String, params: CreateLabelParams) async throws -> GLLabel {
        try await post(path: "groups/\(Self.encodePath(group))/labels", body: params)
    }
}
