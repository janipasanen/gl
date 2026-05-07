import XCTest
@testable import GitLabCore

final class LabelAPITests: XCTestCase {

    func testListLabels() async throws {
        stubRaw(json: Fixtures.labelsArrayJSON)
        let client = makeTestClient()
        let labels = try await client.listLabels(project: "mygroup/my-project")
        XCTAssertEqual(labels.count, 1)
        let l = labels[0]
        XCTAssertEqual(l.id, 7)
        XCTAssertEqual(l.name, "bug")
        XCTAssertEqual(l.color, "#d9534f")
    }

    func testGetLabel() async throws {
        stubRaw(json: Fixtures.labelJSON)
        let client = makeTestClient()
        let l = try await client.getLabel(project: "p", labelId: 7)
        XCTAssertEqual(l.name, "bug")
    }

    func testCreateLabel() async throws {
        stubRaw(status: 201, json: Fixtures.labelJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.labelJSON.utf8))
        }
        let client = makeTestClient()
        let params = CreateLabelParams(name: "bug", color: "#d9534f", description: "Something broken")
        let l = try await client.createLabel(project: "p", params: params)
        XCTAssertEqual(l.name, "bug")
        XCTAssertEqual(capturedBody?["name"] as? String, "bug")
        XCTAssertEqual(capturedBody?["color"] as? String, "#d9534f")
        XCTAssertNil(capturedBody?["priority"])
    }

    func testUpdateLabel() async throws {
        stubRaw(json: Fixtures.labelJSON)
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { req in
            capturedBody = try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(Fixtures.labelJSON.utf8))
        }
        let client = makeTestClient()
        let params = UpdateLabelParams(newName: "defect", color: "#ff0000")
        _ = try await client.updateLabel(project: "p", labelId: 7, params: params)
        XCTAssertEqual(capturedBody?["new_name"] as? String, "defect")
        XCTAssertEqual(capturedBody?["color"] as? String, "#ff0000")
        XCTAssertNil(capturedBody?["description"])
    }

    func testDeleteLabel() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let client = makeTestClient()
        try await client.deleteLabel(project: "p", labelId: 7)
        XCTAssertEqual(capturedMethod, "DELETE")
    }

    func testListGroupLabels() async throws {
        stubRaw(json: Fixtures.labelsArrayJSON)
        let client = makeTestClient()
        let labels = try await client.listGroupLabels(group: "mygroup")
        XCTAssertEqual(labels.count, 1)
    }
}
