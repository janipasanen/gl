import Foundation

extension GitLabAPIClient {

    /// List notes (comments) on a project issue.
    public func listIssueNotes(
        project: String,
        issueIid: Int,
        page: Int = 1,
        perPage: Int = 50
    ) async throws -> [GLNote] {
        try await get(
            path: "projects/\(Self.encodePath(project))/issues/\(issueIid)/notes",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Get a single note on an issue.
    public func getIssueNote(project: String, issueIid: Int, noteId: Int) async throws -> GLNote {
        try await get(path: "projects/\(Self.encodePath(project))/issues/\(issueIid)/notes/\(noteId)")
    }

    /// Create a note on an issue.
    public func createIssueNote(project: String, issueIid: Int, body: String) async throws -> GLNote {
        try await post(
            path: "projects/\(Self.encodePath(project))/issues/\(issueIid)/notes",
            body: CreateNoteParams(body: body)
        )
    }

    /// Update an existing note on an issue.
    public func updateIssueNote(project: String, issueIid: Int, noteId: Int, body: String) async throws -> GLNote {
        try await put(
            path: "projects/\(Self.encodePath(project))/issues/\(issueIid)/notes/\(noteId)",
            body: UpdateNoteParams(body: body)
        )
    }

    /// Delete a note on an issue.
    public func deleteIssueNote(project: String, issueIid: Int, noteId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/issues/\(issueIid)/notes/\(noteId)")
    }
}
