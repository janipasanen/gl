import Foundation
import GitLabCore

// MARK: - Mock URL protocol

/// Intercepts all URLSession requests and delegates to `requestHandler`.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// Set this before each test to return the desired response.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            var req = request
            if req.httpBody == nil, let stream = req.httpBodyStream {
                stream.open()
                var bodyData = Data()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let count = stream.read(buffer, maxLength: 4096)
                    if count > 0 { bodyData.append(buffer, count: count) }
                }
                stream.close()
                req.httpBody = bodyData
            }
            let (response, data) = try handler(req)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

/// Build a `GitLabAPIClient` that uses `MockURLProtocol`.
func makeTestClient() -> GitLabAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    return GitLabAPIClient(
        baseURL: URL(string: "https://gitlab.example.com")!,
        token: "test-token",
        session: session
    )
}

/// Register a handler that returns `statusCode` and JSON-encoded `body`.
func stub<T: Encodable>(status: Int = 200, body: T) {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = (try? encoder.encode(body)) ?? Data()
    MockURLProtocol.requestHandler = { req in
        let url = req.url ?? URL(string: "https://gitlab.example.com")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }
}

/// Register a handler that returns a raw JSON string.
func stubRaw(status: Int = 200, json: String) {
    MockURLProtocol.requestHandler = { req in
        let url = req.url ?? URL(string: "https://gitlab.example.com")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, Data(json.utf8))
    }
}
