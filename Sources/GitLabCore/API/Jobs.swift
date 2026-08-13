import Foundation

extension GitLabAPIClient {

    /// List CI jobs — for one pipeline when `pipelineId` is given, otherwise for
    /// the whole project.
    ///
    /// Two different endpoints back this call:
    /// - `GET /projects/:id/pipelines/:pipeline_id/jobs` when `pipelineId` is set
    /// - `GET /projects/:id/jobs` when it is not
    ///
    /// GitLab filters jobs with **`scope`**, not `status`: sending
    /// `status=failed` is ignored and silently returns *every* job. `scope` is
    /// an array parameter, so each value is sent as `scope[]=<value>`
    /// (percent-encoded as `scope%5B%5D=`, which Rack unescapes back into an
    /// array before parsing). `status` may be a comma-separated list.
    ///
    /// Because a server that ignores the parameter would degrade `--status`
    /// into "no filter at all", the returned page is *also* filtered locally on
    /// `status`. `ref` is filtered locally only — neither jobs endpoint accepts
    /// a `ref` parameter. Both filters therefore apply to the requested page,
    /// not to the whole job history; widen `perPage` when filtering.
    public func listJobs(
        project: String,
        pipelineId: Int? = nil,
        ref: String? = nil,
        status: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GLJob] {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(perPage)"),
        ]
        let scopes = Self.jobScopes(status)
        for scope in scopes {
            items.append(.init(name: "scope[]", value: scope))
        }

        let base = "projects/\(Self.encodePath(project))"
        let path = pipelineId.map { "\(base)/pipelines/\($0)/jobs" } ?? "\(base)/jobs"
        let jobs: [GLJob] = try await get(path: path, queryItems: items)

        var result = jobs
        if !scopes.isEmpty {
            let wanted = Set(scopes.map { $0.lowercased() })
            result = result.filter { wanted.contains($0.status.lowercased()) }
        }
        if let ref, !ref.isEmpty {
            result = result.filter { $0.ref == ref }
        }
        return result
    }

    /// Get a single job by ID.
    public func getJob(project: String, jobId: Int) async throws -> GLJob {
        try await get(path: "projects/\(Self.encodePath(project))/jobs/\(jobId)")
    }

    /// Fetch a job's log ("trace") exactly as GitLab returns it.
    ///
    /// `GET /projects/:id/jobs/:job_id/trace` responds with **text/plain**, not
    /// JSON, so this deliberately bypasses the `Decodable` `get` helper and
    /// decodes the body as UTF-8 itself — while still running `checkResponse`,
    /// so a 404 (unknown job, or a job whose log has been erased) still
    /// surfaces as `ClientError.apiError`.
    ///
    /// The text comes back raw: ANSI colour escapes, `section_start:` /
    /// `section_end:` fold markers and per-line RFC3339 timestamps included.
    /// Run it through `Formatter.cleanJobTrace(_:)` to make it readable.
    public func jobTrace(project: String, jobId: Int) async throws -> String {
        let (data, response) = try await request(
            path: "projects/\(Self.encodePath(project))/jobs/\(jobId)/trace"
        )
        try checkResponse(response, data: data)
        return String(decoding: data, as: UTF8.self)
    }

    /// Retry a job. Returns the newly created job.
    public func retryJob(project: String, jobId: Int) async throws -> GLJob {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/jobs/\(jobId)/retry",
            body: Empty()
        )
    }

    /// Cancel a running job.
    public func cancelJob(project: String, jobId: Int) async throws -> GLJob {
        struct Empty: Encodable {}
        return try await post(
            path: "projects/\(Self.encodePath(project))/jobs/\(jobId)/cancel",
            body: Empty()
        )
    }

    /// Download a job's artifacts archive.
    ///
    /// `GET /projects/:id/jobs/:job_id/artifacts` responds with a binary **zip**
    /// (often after a redirect to object storage), so this returns the bytes
    /// untouched — putting them through the JSON or UTF-8 helpers would corrupt
    /// the archive. Callers write the `Data` to disk; never print it.
    public func jobArtifacts(project: String, jobId: Int) async throws -> Data {
        let (data, response) = try await request(
            path: "projects/\(Self.encodePath(project))/jobs/\(jobId)/artifacts"
        )
        try checkResponse(response, data: data)
        return data
    }

    /// Split a comma-separated `--status` value into GitLab job scopes.
    static func jobScopes(_ status: String?) -> [String] {
        guard let raw = status?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return []
        }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
