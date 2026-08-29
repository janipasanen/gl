import XCTest
@testable import GitLabCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class JobAPITests: XCTestCase {

    // MARK: - list: endpoint selection

    func testListJobsForPipelineUsesPipelineEndpoint() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "mygroup/my-project", pipelineId: 300)
        XCTAssertEqual(jobs.count, 2)
        // The project path must be percent-encoded and the pipeline id must be
        // in the path — this is the endpoint that answers "which job failed?".
        XCTAssertEqual(
            capturedURL?.absoluteString.contains("/api/v4/projects/mygroup%2Fmy-project/pipelines/300/jobs"),
            true,
            "expected the pipeline jobs endpoint, got \(capturedURL?.absoluteString ?? "nil")"
        )
    }

    func testListJobsWithoutPipelineUsesProjectEndpoint() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listJobs(project: "mygroup/my-project")
        let url = capturedURL?.absoluteString ?? ""
        XCTAssertTrue(url.contains("/api/v4/projects/mygroup%2Fmy-project/jobs"), url)
        XCTAssertFalse(url.contains("/pipelines/"), url)
    }

    // MARK: - list: filtering

    func testListJobsStatusUsesScopeArrayNotStatus() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listJobs(project: "p", pipelineId: 300, status: "failed")
        let query = capturedQuery ?? ""
        // GitLab jobs are filtered with scope[], not status=; `status=failed`
        // is silently ignored and returns every job.
        XCTAssertTrue(query.contains("scope%5B%5D=failed"), "expected scope[]=failed, got \(query)")
        XCTAssertFalse(query.contains("status="), "must not send status=, got \(query)")
    }

    func testListJobsSendsOneScopeItemPerStatus() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", status: "failed, running")
        let query = capturedQuery ?? ""
        XCTAssertTrue(query.contains("scope%5B%5D=failed"), query)
        XCTAssertTrue(query.contains("scope%5B%5D=running"), query)
        XCTAssertEqual(jobs.count, 2)
    }

    func testListJobsStatusNeverSilentlyReturnsEverything() async throws {
        // The stub answers with BOTH jobs, exactly as a server that ignored the
        // filter would. --status failed must still yield only the failed job.
        stubRaw(json: Fixtures.jobsArrayJSON)
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", pipelineId: 300, status: "failed")
        XCTAssertEqual(jobs.map(\.id), [4001])
        XCTAssertEqual(jobs.first?.status, "failed")
    }

    func testListJobsRefFilterIsAppliedLocally() async throws {
        stubRaw(json: Fixtures.jobsArrayJSON)
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", ref: "main")
        XCTAssertEqual(jobs.map(\.id), [4002])
    }

    func testListJobsPagination() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listJobs(project: "p", page: 3, perPage: 50)
        XCTAssertTrue(capturedQuery?.contains("page=3") == true)
        XCTAssertTrue(capturedQuery?.contains("per_page=50") == true)
    }

    // MARK: - Decoding

    func testJobDecodesStageStatusAndDuration() async throws {
        stubRaw(json: Fixtures.jobsArrayJSON)
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", pipelineId: 300)
        let failed = try XCTUnwrap(jobs.first)
        XCTAssertEqual(failed.id, 4001)
        XCTAssertEqual(failed.name, "tests")
        XCTAssertEqual(failed.stage, "test")
        XCTAssertEqual(failed.status, "failed")
        XCTAssertEqual(failed.ref, "develop")
        XCTAssertEqual(failed.failureReason, "script_failure")
        XCTAssertEqual(failed.duration ?? 0, 63.788263, accuracy: 0.0001)
        XCTAssertEqual(failed.pipeline?.id, 300)
        XCTAssertEqual(failed.user?.username, "jdoe")
        XCTAssertEqual(failed.artifactsFile?.filename, "artifacts.zip")
        XCTAssertNotNil(failed.finishedAt)
    }

    func testJobDecodesUnfinishedJobWithNullFields() async throws {
        stubRaw(json: Fixtures.jobsArrayJSON)
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", pipelineId: 300)
        let running = try XCTUnwrap(jobs.last)
        XCTAssertEqual(running.id, 4002)
        XCTAssertEqual(running.stage, "verify")
        XCTAssertNil(running.duration)
        XCTAssertNil(running.finishedAt)
        XCTAssertNil(running.user)
        XCTAssertNil(running.artifactsFile)
    }

    // MARK: - get

    func testGetJob() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobFailedJSON.utf8))
        }
        let client = makeTestClient()
        let job = try await client.getJob(project: "mygroup/my-project", jobId: 4001)
        XCTAssertEqual(job.id, 4001)
        XCTAssertEqual(
            capturedURL?.absoluteString.hasSuffix("/api/v4/projects/mygroup%2Fmy-project/jobs/4001"),
            true,
            capturedURL?.absoluteString ?? "nil"
        )
    }

    // MARK: - trace

    func testJobTraceIsPlainTextNotJSON() async throws {
        // The body is a raw log, not JSON: routing it through the Decodable
        // `get` helper would throw here.
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (r, Data(Fixtures.jobTraceRawText.utf8))
        }
        let client = makeTestClient()
        let trace = try await client.jobTrace(project: "mygroup/my-project", jobId: 4001)
        XCTAssertEqual(trace, Fixtures.jobTraceRawText)
        XCTAssertEqual(
            capturedURL?.absoluteString.hasSuffix("/api/v4/projects/mygroup%2Fmy-project/jobs/4001/trace"),
            true,
            capturedURL?.absoluteString ?? "nil"
        )
    }

    func testJobTrace404SurfacesAPIError() async {
        stubRaw(status: 404, json: "404 Job Not Found")
        let client = makeTestClient()
        do {
            _ = try await client.jobTrace(project: "p", jobId: 4001)
            XCTFail("expected a 404 to throw")
        } catch let error as GitLabAPIClient.ClientError {
            guard case .apiError(let code, _) = error else {
                return XCTFail("expected apiError, got \(error)")
            }
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("expected ClientError.apiError, got \(error)")
        }
    }

    func testCleanJobTraceStripsAnsiSectionsTimestampsAndProgress() {
        let cleaned = Formatter.cleanJobTrace(Fixtures.jobTraceRawText)
        XCTAssertEqual(cleaned, Fixtures.jobTraceCleanText)
        XCTAssertFalse(cleaned.contains("\u{1B}"), "ANSI escapes must be gone")
        XCTAssertFalse(cleaned.contains("section_start:"))
        XCTAssertFalse(cleaned.contains("section_end:"))
        XCTAssertFalse(cleaned.contains("2024-03-01T10:00:05"))
        XCTAssertFalse(cleaned.contains("\r"))
        // The stream markers go with the timestamp — including the `00O+`
        // continuation form, which has no space before the text.
        XCTAssertFalse(cleaned.contains("00O"), cleaned)
        XCTAssertFalse(cleaned.contains("01O"), cleaned)
        XCTAssertTrue(cleaned.contains("FAIL src/foo.test.ts"))
    }

    func testCleanJobTraceStripsEveryStreamMarkerForm() {
        XCTAssertEqual(Formatter.cleanJobTrace("2024-03-01T10:00:00.000000Z 00O out\n"), "out\n")
        XCTAssertEqual(Formatter.cleanJobTrace("2024-03-01T10:00:00.000000Z 01E err\n"), "err\n")
        XCTAssertEqual(Formatter.cleanJobTrace("2024-03-01T10:00:00.000000Z 00O+cont\n"), "cont\n")
        XCTAssertEqual(Formatter.cleanJobTrace("2024-03-01T10:00:00+02:00 00O offset\n"), "offset\n")
        // No marker at all (older GitLab) — just the timestamp.
        XCTAssertEqual(Formatter.cleanJobTrace("2024-03-01T10:00:00Z plain\n"), "plain\n")
    }

    func testCleanJobTraceKeepsBlankLinesButDropsMarkerOnlyLines() {
        let raw = "first\n\nsection_end:1709287260:step_script\r\u{1B}[0K\nlast\n"
        XCTAssertEqual(Formatter.cleanJobTrace(raw), "first\n\nlast\n")
    }

    func testTailLinesKeepsOnlyTheLastLines() {
        let tailed = Formatter.tailLines(Fixtures.jobTraceCleanText, count: 2)
        XCTAssertEqual(tailed, "FAIL src/foo.test.ts\nERROR: Job failed: exit code 1\n")
    }

    func testTailLinesShorterThanRequestedIsUnchanged() {
        XCTAssertEqual(Formatter.tailLines("a\nb\n", count: 10), "a\nb\n")
        XCTAssertEqual(Formatter.tailLines("a\nb", count: 2), "a\nb")
    }

    // MARK: - retry / cancel

    func testRetryJobPostsToRetryEndpoint() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobFailedJSON.utf8))
        }
        let client = makeTestClient()
        let job = try await client.retryJob(project: "p", jobId: 4001)
        XCTAssertEqual(job.id, 4001)
        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedURL?.absoluteString.hasSuffix("/jobs/4001/retry"), true,
                       capturedURL?.absoluteString ?? "nil")
    }

    func testCancelJobPostsToCancelEndpoint() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobFailedJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.cancelJob(project: "p", jobId: 4001)
        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedURL?.absoluteString.hasSuffix("/jobs/4001/cancel"), true,
                       capturedURL?.absoluteString ?? "nil")
    }

    // MARK: - artifacts

    /// A zip that is deliberately not valid UTF-8, so any String round-trip
    /// would corrupt it.
    private static let zipBytes = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFE, 0x00, 0x01, 0x80])

    func testJobArtifactsReturnsBinaryDataUnchanged() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/zip"]
            )!
            return (r, Self.zipBytes)
        }
        let client = makeTestClient()
        let data = try await client.jobArtifacts(project: "mygroup/my-project", jobId: 4001)
        XCTAssertEqual(data, Self.zipBytes)
        XCTAssertEqual(
            capturedURL?.absoluteString.hasSuffix("/api/v4/projects/mygroup%2Fmy-project/jobs/4001/artifacts"),
            true,
            capturedURL?.absoluteString ?? "nil"
        )
    }

    func testArtifactsCommandWritesFileAndReportsBytes() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Self.zipBytes)
        }
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("gl-artifacts-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: target) }

        let cmd = try GLCommand.parse(
            arguments: ["jobs", "artifacts", "p", "4001", "--output", target.path])
        let output = try await cmd.run(client: makeTestClient())

        XCTAssertEqual(try Data(contentsOf: target), Self.zipBytes)
        XCTAssertTrue(output.contains(target.path), output)
        XCTAssertTrue(output.contains("\(Self.zipBytes.count) bytes"), output)
        // The archive itself must never be printed.
        XCTAssertFalse(output.contains("PK"), output)
    }

    // MARK: - CLI

    func testJobsListCommandUsesPipelineFlag() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let cmd = try GLCommand.parse(arguments: ["jobs", "list", "zesec/kiion-crm", "--pipeline", "2757878718"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertEqual(
            capturedURL?.absoluteString.contains("/projects/zesec%2Fkiion-crm/pipelines/2757878718/jobs"),
            true,
            capturedURL?.absoluteString ?? "nil"
        )
        // Stage and status are both required to see where a run broke.
        XCTAssertTrue(output.contains("Stage"), output)
        XCTAssertTrue(output.contains("Status"), output)
        XCTAssertTrue(output.contains("failed"), output)
        XCTAssertTrue(output.contains("test"), output)
        XCTAssertTrue(output.contains("tests"), output)
    }

    func testJobsListCommandStatusFilter() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.jobsArrayJSON.utf8))
        }
        let cmd = try GLCommand.parse(arguments: ["jobs", "list", "p", "--status", "failed"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(capturedQuery?.contains("scope%5B%5D=failed") == true, capturedQuery ?? "nil")
        XCTAssertTrue(output.contains("4001"), output)
        XCTAssertFalse(output.contains("4002"), output)
    }

    func testJobsGetCommand() async throws {
        stubRaw(json: Fixtures.jobFailedJSON)
        let cmd = try GLCommand.parse(arguments: ["jobs", "get", "p", "4001"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("script_failure"), output)
        XCTAssertTrue(output.contains("test"), output)
    }

    func testJobsTraceCommandCleansByDefault() async throws {
        stubRaw(json: Fixtures.jobTraceRawText)
        let cmd = try GLCommand.parse(arguments: ["jobs", "trace", "p", "4001"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertEqual(output, Fixtures.jobTraceCleanText)
    }

    func testJobsTraceCommandRawKeepsBytesUntouched() async throws {
        stubRaw(json: Fixtures.jobTraceRawText)
        // --raw must not swallow the following positional either.
        let cmd = try GLCommand.parse(arguments: ["jobs", "trace", "--raw", "p", "4001"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertEqual(output, Fixtures.jobTraceRawText)
    }

    func testJobsTraceCommandTail() async throws {
        stubRaw(json: Fixtures.jobTraceRawText)
        let cmd = try GLCommand.parse(arguments: ["jobs", "trace", "p", "4001", "--tail", "2"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertEqual(output, "FAIL src/foo.test.ts\nERROR: Job failed: exit code 1\n")
    }

    func testJobsTraceCommandTailAppliesToRawToo() async throws {
        stubRaw(json: Fixtures.jobTraceRawText)
        let cmd = try GLCommand.parse(arguments: ["jobs", "trace", "p", "4001", "--tail", "2", "--raw"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("\u{1B}[31;1mERROR: Job failed: exit code 1"), output)
        XCTAssertFalse(output.contains("Running with gitlab-runner"), output)
    }

    func testJobsTraceCommandJSONWrapsTheLog() async throws {
        stubRaw(json: Fixtures.jobTraceRawText)
        let cmd = try GLCommand.parse(arguments: ["jobs", "trace", "p", "4001", "--json"])
        let output = try await cmd.run(client: makeTestClient())
        let object = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
        XCTAssertEqual(object?["job_id"] as? Int, 4001)
        XCTAssertEqual(object?["trace"] as? String, Fixtures.jobTraceCleanText)
    }

    func testJobsTraceCommandRejectsNonNumericJobId() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["jobs", "trace", "p", "abc"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("job-id"), error.localizedDescription)
        }
    }

    func testUnknownJobsSubcommandThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["jobs", "frobnicate", "p"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("jobs frobnicate"), error.localizedDescription)
        }
    }

    func testHelpDocumentsJobs() {
        let help = GLCommand.helpText
        XCTAssertTrue(help.contains("jobs list"))
        XCTAssertTrue(help.contains("--pipeline <id>"))
        XCTAssertTrue(help.contains("jobs get"))
        XCTAssertTrue(help.contains("jobs trace"))
        XCTAssertTrue(help.contains("--tail <n>"))
        XCTAssertTrue(help.contains("--raw"))
        XCTAssertTrue(help.contains("jobs retry"))
        XCTAssertTrue(help.contains("jobs cancel"))
        XCTAssertTrue(help.contains("jobs artifacts"))
    }

    // MARK: - Formatting

    func testFormatJobsTableShowsStageAndDuration() async throws {
        stubRaw(json: Fixtures.jobsArrayJSON)
        let client = makeTestClient()
        let jobs = try await client.listJobs(project: "p", pipelineId: 300)
        let table = Formatter.formatJobs(jobs, json: false)
        XCTAssertTrue(table.contains("verify"), table)
        XCTAssertTrue(table.contains("1m 4s"), table)
    }

    func testHumanDuration() {
        XCTAssertEqual(Formatter.humanDuration(nil), "")
        XCTAssertEqual(Formatter.humanDuration(9.4), "9s")
        XCTAssertEqual(Formatter.humanDuration(63.788263), "1m 4s")
        XCTAssertEqual(Formatter.humanDuration(3720), "1h 2m")
    }
}
