import Foundation

extension GitLabAPIClient {

    /// List notes (comments) on a merge request.
    public func listMRNotes(project: String, mrIid: Int, page: Int = 1, perPage: Int = 50) async throws -> [GLNote] {
        try await get(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(mrIid)/notes",
            queryItems: [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    /// Get a single note on a merge request.
    public func getMRNote(project: String, mrIid: Int, noteId: Int) async throws -> GLNote {
        try await get(path: "projects/\(Self.encodePath(project))/merge_requests/\(mrIid)/notes/\(noteId)")
    }

    /// Create a note on a merge request.
    public func createMRNote(project: String, mrIid: Int, body: String) async throws -> GLNote {
        try await post(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(mrIid)/notes",
            body: CreateNoteParams(body: body)
        )
    }

    /// Update an existing note on a merge request.
    public func updateMRNote(project: String, mrIid: Int, noteId: Int, body: String) async throws -> GLNote {
        try await put(
            path: "projects/\(Self.encodePath(project))/merge_requests/\(mrIid)/notes/\(noteId)",
            body: UpdateNoteParams(body: body)
        )
    }

    /// Delete a note on a merge request.
    public func deleteMRNote(project: String, mrIid: Int, noteId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/merge_requests/\(mrIid)/notes/\(noteId)")
    }
}
