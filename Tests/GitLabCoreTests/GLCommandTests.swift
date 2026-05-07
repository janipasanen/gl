import XCTest
@testable import GitLabCore

final class GLCommandTests: XCTestCase {

    // MARK: - Parse

    func testNoArgsDefaultsToWhoami() async throws {
        stubRaw(json: Fixtures.userJSON)
        let cmd = try GLCommand.parse(arguments: [])
        let client = makeTestClient()
        // Should not throw
        let output = try await cmd.run(client: client)
        XCTAssertTrue(output.contains("jdoe") || output.contains("Jane Doe"))
    }

    func testWhoamiCommand() async throws {
        stubRaw(json: Fixtures.userJSON)
        let cmd = try GLCommand.parse(arguments: ["whoami"])
        let client = makeTestClient()
        let output = try await cmd.run(client: client)
        XCTAssertTrue(output.contains("jdoe"))
    }

    func testHelpCommand() async throws {
        let cmd = try GLCommand.parse(arguments: ["help"])
        let client = makeTestClient()
        let output = try await cmd.run(client: client)
        XCTAssertTrue(output.contains("USAGE"))
        XCTAssertTrue(output.contains("ENVIRONMENT"))
    }

    func testUnknownCommandThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["unknown-resource"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unknown command"))
        }
    }

    // MARK: - projects

    func testProjectsListCommand() async throws {
        stubRaw(json: Fixtures.projectsArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["projects", "list"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("mygroup/my-project"))
    }

    func testProjectGetCommand() async throws {
        stubRaw(json: Fixtures.projectJSON)
        let cmd = try GLCommand.parse(arguments: ["projects", "get", "mygroup/my-project"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("mygroup/my-project"))
    }

    func testProjectShorthandCommand() async throws {
        stubRaw(json: Fixtures.projectJSON)
        let cmd = try GLCommand.parse(arguments: ["project", "mygroup/my-project"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("My Project"))
    }

    func testProjectMissingArgThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["project"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Missing argument"))
        }
    }

    // MARK: - issues

    func testIssuesListCommand() async throws {
        stubRaw(json: Fixtures.issuesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "list", "mygroup/my-project", "--state", "open"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("Fix the bug"))
    }

    func testIssuesListMissingProjectThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["issues", "list"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Missing argument"))
        }
    }

    func testIssuesGetCommand() async throws {
        stubRaw(json: Fixtures.issueJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "get", "mygroup/my-project", "1"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("Fix the bug"))
        XCTAssertTrue(output.contains("asmith"))
    }

    func testIssuesGetInvalidIIDThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["issues", "get", "p", "notAnInt"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("not a valid integer"))
        }
    }

    func testIssuesCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.issueJSON)
        let cmd = try GLCommand.parse(arguments: [
            "issues", "create", "mygroup/my-project",
            "--title", "Fix the bug", "--labels", "bug,high", "--weight", "5",
        ])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("Fix the bug"))
    }

    func testIssuesCreateMissingTitleThrows() {
        XCTAssertThrowsError(try GLCommand.parse(arguments: ["issues", "create", "p"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Missing argument"))
        }
    }

    func testIssuesCloseCommand() async throws {
        stubRaw(json: Fixtures.issueJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "close", "p", "1"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    func testIssuesDeleteCommand() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let cmd = try GLCommand.parse(arguments: ["issues", "delete", "p", "1"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("deleted"))
    }

    func testIssuesNotesListCommand() async throws {
        stubRaw(json: Fixtures.notesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "notes", "list", "p", "1"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("This is a comment"))
    }

    func testIssuesNotesCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.noteJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "notes", "create", "p", "1", "--body", "Hello"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    // MARK: - milestones

    func testMilestonesListCommand() async throws {
        stubRaw(json: Fixtures.milestonesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["milestones", "list", "mygroup/my-project"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("v1.0"))
    }

    func testMilestonesCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.milestoneJSON)
        let cmd = try GLCommand.parse(arguments: [
            "milestones", "create", "p", "--title", "v1.0",
            "--due-date", "2024-03-31", "--start-date", "2024-01-01",
        ])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("v1.0"))
    }

    func testMilestonesDeleteCommand() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let cmd = try GLCommand.parse(arguments: ["milestones", "delete", "p", "10"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("deleted"))
    }

    // MARK: - mr

    func testMRListCommand() async throws {
        stubRaw(json: Fixtures.mrsArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["mr", "list", "mygroup/my-project", "--state", "opened"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("!3"))
    }

    func testMRGetCommand() async throws {
        stubRaw(json: Fixtures.mrJSON)
        let cmd = try GLCommand.parse(arguments: ["mr", "get", "p", "3"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("feature/x"))
    }

    func testMRCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.mrJSON)
        let cmd = try GLCommand.parse(arguments: [
            "mr", "create", "p",
            "--source", "feature/x", "--target", "main", "--title", "Add feature X",
        ])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    func testMRMergeCommand() async throws {
        stubRaw(json: Fixtures.mrJSON)
        let cmd = try GLCommand.parse(arguments: ["mr", "merge", "p", "3"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    func testMRNotesListCommand() async throws {
        stubRaw(json: Fixtures.notesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["mr", "notes", "list", "p", "3"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("This is a comment"))
    }

    // MARK: - labels

    func testLabelsListCommand() async throws {
        stubRaw(json: Fixtures.labelsArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["labels", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("bug"))
        XCTAssertTrue(output.contains("#d9534f"))
    }

    func testLabelsCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.labelJSON)
        let cmd = try GLCommand.parse(arguments: ["labels", "create", "p", "--name", "bug", "--color", "#d9534f"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("bug"))
    }

    func testLabelsDeleteCommand() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let cmd = try GLCommand.parse(arguments: ["labels", "delete", "p", "7"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("deleted"))
    }

    // MARK: - groups

    func testGroupsListCommand() async throws {
        stubRaw(json: Fixtures.groupsArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["groups", "list"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("mygroup"))
    }

    func testGroupsGetCommand() async throws {
        stubRaw(json: Fixtures.groupJSON)
        let cmd = try GLCommand.parse(arguments: ["groups", "get", "mygroup"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("My Group"))
    }

    func testGroupsMilestonesListCommand() async throws {
        stubRaw(json: Fixtures.milestonesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["groups", "milestones", "list", "mygroup"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("v1.0"))
    }

    // MARK: - members

    func testMembersListCommand() async throws {
        stubRaw(json: Fixtures.membersArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["members", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("asmith"))
        XCTAssertTrue(output.contains("Developer"))
    }

    func testMembersAddCommand() async throws {
        stubRaw(status: 201, json: Fixtures.memberJSON)
        let cmd = try GLCommand.parse(arguments: ["members", "add", "p", "--user", "2", "--access-level", "30"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("asmith"))
    }

    func testMembersRemoveCommand() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let cmd = try GLCommand.parse(arguments: ["members", "remove", "p", "--user", "2"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("removed"))
    }

    // MARK: - branches

    func testBranchesListCommand() async throws {
        stubRaw(json: Fixtures.branchesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["branches", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("main"))
    }

    func testBranchesCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.branchJSON)
        let cmd = try GLCommand.parse(arguments: ["branches", "create", "p", "--name", "feature/x", "--ref", "main"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    func testBranchesDeleteCommand() async throws {
        MockURLProtocol.requestHandler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (r, Data())
        }
        let cmd = try GLCommand.parse(arguments: ["branches", "delete", "p", "feature/old"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("deleted"))
    }

    // MARK: - pipelines

    func testPipelinesListCommand() async throws {
        stubRaw(json: Fixtures.pipelinesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["pipelines", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("300"))
        XCTAssertTrue(output.contains("success"))
    }

    func testPipelinesCancelCommand() async throws {
        stubRaw(json: Fixtures.pipelineJSON)
        let cmd = try GLCommand.parse(arguments: ["pipelines", "cancel", "p", "300"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertFalse(output.isEmpty)
    }

    // MARK: - releases

    func testReleasesListCommand() async throws {
        stubRaw(json: Fixtures.releasesArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["releases", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("v1.0.0"))
    }

    func testReleasesCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.releaseJSON)
        let cmd = try GLCommand.parse(arguments: [
            "releases", "create", "p",
            "--tag", "v1.0.0", "--name", "Version 1.0.0",
        ])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("v1.0.0"))
    }

    // MARK: - workitems

    func testWorkitemsListCommand() async throws {
        stubRaw(json: Fixtures.workItemsArrayJSON)
        let cmd = try GLCommand.parse(arguments: ["workitems", "list", "p"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("My work item"))
    }

    func testWorkitemsCreateCommand() async throws {
        stubRaw(status: 201, json: Fixtures.workItemJSON)
        let cmd = try GLCommand.parse(arguments: ["workitems", "create", "p", "--title", "My work item"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.contains("My work item"))
    }

    // MARK: - JSON flag

    func testJsonFlagProducesJSON() async throws {
        stubRaw(json: Fixtures.issueJSON)
        let cmd = try GLCommand.parse(arguments: ["issues", "get", "p", "1", "--json"])
        let output = try await cmd.run(client: makeTestClient())
        XCTAssertTrue(output.hasPrefix("{"))
        XCTAssertTrue(output.contains("\"iid\""))
    }
}
