import Foundation

extension GitLabAPIClient {

    /// List pipelines for a project.
    public func listPipelines(
        project: String,
        ref: String? = nil,
        status: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLPipeline] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        if let v = ref    { items.append(.init(name: "ref", value: v)) }
        if let v = status { items.append(.init(name: "status", value: v)) }
        return try await get(path: "projects/\(Self.encodePath(project))/pipelines", queryItems: items)
    }

    /// Get a single pipeline by ID.
    public func getPipeline(project: String, pipelineId: Int) async throws -> GLPipeline {
        try await get(path: "projects/\(Self.encodePath(project))/pipelines/\(pipelineId)")
    }

    /// Cancel a running pipeline.
    public func cancelPipeline(project: String, pipelineId: Int) async throws -> GLPipeline {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/pipelines/\(pipelineId)/cancel",
            body: Empty()
        )
    }

    /// Retry a failed pipeline.
    public func retryPipeline(project: String, pipelineId: Int) async throws -> GLPipeline {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/pipelines/\(pipelineId)/retry",
            body: Empty()
        )
    }

    /// Delete a pipeline.
    public func deletePipeline(project: String, pipelineId: Int) async throws {
        try await delete(path: "projects/\(Self.encodePath(project))/pipelines/\(pipelineId)")
    }

    /// Create (trigger) a new pipeline on a ref.
    public func createPipeline(project: String, ref: String) async throws -> GLPipeline {
        struct Body: Encodable { let ref: String }
        return try await post(
            path: "projects/\(Self.encodePath(project))/pipeline",
            body: Body(ref: ref)
        )
    }
}
