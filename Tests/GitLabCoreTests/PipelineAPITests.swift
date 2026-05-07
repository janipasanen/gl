import XCTest
@testable import GitLabCore

final class PipelineAPITests: XCTestCase {

    func testListPipelines() async throws {
        stubRaw(json: Fixtures.pipelinesArrayJSON)
        let client = makeTestClient()
        let pipelines = try await client.listPipelines(project: "mygroup/my-project")
        XCTAssertEqual(pipelines.count, 1)
        let p = pipelines[0]
        XCTAssertEqual(p.id, 300)
        XCTAssertEqual(p.status, "success")
        XCTAssertEqual(p.ref, "main")
    }

    func testListPipelinesQueryParams() async throws {
        var capturedQuery: String?
        MockURLProtocol.requestHandler = { req in
            capturedQuery = req.url?.query
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.pipelinesArrayJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.listPipelines(project: "p", ref: "develop", status: "running")
        XCTAssertTrue(capturedQuery?.contains("ref=develop") == true)
        XCTAssertTrue(capturedQuery?.contains("status=running") == true)
    }

    func testGetPipeline() async throws {
        stubRaw(json: Fixtures.pipelineJSON)
        let client = makeTestClient()
        let p = try await client.getPipeline(project: "p", pipelineId: 300)
        XCTAssertEqual(p.id, 300)
        XCTAssertEqual(p.sha, "abc123def456789")
    }

    func testCancelPipeline() async throws {
        stubRaw(json: Fixtures.pipelineJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.pipelineJSON.utf8))
        }
        let client = makeTestClient()
        let p = try await client.cancelPipeline(project: "p", pipelineId: 300)
        XCTAssertEqual(p.id, 300)
        XCTAssertTrue(capturedURL?.path.contains("cancel") == true)
    }

    func testRetryPipeline() async throws {
        stubRaw(json: Fixtures.pipelineJSON)
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.pipelineJSON.utf8))
        }
        let client = makeTestClient()
        _ = try await client.retryPipeline(project: "p", pipelineId: 300)
        XCTAssertTrue(capturedURL?.path.contains("retry") == true)
    }

    func testDeletePipeline() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deletePipeline(project: "p", pipelineId: 300)
        XCTAssertEqual(capturedMethod, "DELETE")
    }
}
