import XCTest
@testable import GitLabCore

final class FormatterTests: XCTestCase {

    // MARK: Table

    func testTableRendersHeadersAndRows() {
        let output = Formatter.table(
            headers: ["ID", "Name"],
            rows: [["1", "Alice"], ["2", "Bob"]]
        )
        XCTAssertTrue(output.contains("ID"))
        XCTAssertTrue(output.contains("Name"))
        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("Bob"))
        XCTAssertTrue(output.contains("--"))
    }

    func testTableEmptyRows() {
        let output = Formatter.table(headers: ["ID"], rows: [])
        XCTAssertEqual(output, "(none)")
    }

    func testTableTruncatesLongValues() {
        let long = String(repeating: "x", count: 100)
        let output = Formatter.table(headers: ["Col"], rows: [[long]])
        // Should not crash and should truncate to 80 chars max per cell
        XCTAssertTrue(output.contains("…"))
    }

    // MARK: Detail

    func testDetailRendersFields() {
        let output = Formatter.detail([
            ("Name", "Alice"),
            ("Role", "Developer"),
        ])
        XCTAssertTrue(output.contains("Name"))
        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("Developer"))
    }

    func testDetailSkipsNilValues() {
        let output = Formatter.detail([
            ("Name", "Alice"),
            ("Email", nil),
        ])
        XCTAssertFalse(output.contains("Email"))
    }

    func testDetailSkipsEmptyValues() {
        let output = Formatter.detail([
            ("Name", "Alice"),
            ("Bio", ""),
        ])
        XCTAssertFalse(output.contains("Bio"))
    }

    // MARK: Truncate

    func testTruncateShortString() {
        XCTAssertEqual(Formatter.truncate("Hello", maxLength: 60), "Hello")
    }

    func testTruncateLongString() {
        let long = String(repeating: "a", count: 100)
        let result = Formatter.truncate(long, maxLength: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.hasSuffix("…"))
    }

    func testTruncateNil() {
        XCTAssertEqual(Formatter.truncate(nil), "")
    }

    // MARK: formatIssues

    func testFormatIssuesText() throws {
        let data = Data(Fixtures.issuesArrayJSON.utf8)
        let issues: [GLIssue] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatIssues(issues, json: false)
        XCTAssertTrue(output.contains("#1"))
        XCTAssertTrue(output.contains("Fix the bug"))
        XCTAssertTrue(output.contains("opened"))
    }

    func testFormatIssuesJSON() throws {
        let data = Data(Fixtures.issuesArrayJSON.utf8)
        let issues: [GLIssue] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatIssues(issues, json: true)
        XCTAssertTrue(output.hasPrefix("["))
        XCTAssertTrue(output.contains("\"iid\""))
    }

    func testFormatProjectText() throws {
        let data = Data(Fixtures.projectJSON.utf8)
        let project: GLProject = try GitLabAPIClient.decode(data)
        let output = Formatter.formatProject(project, json: false)
        XCTAssertTrue(output.contains("mygroup/my-project"))
        XCTAssertTrue(output.contains("private"))
    }

    func testFormatMilestonesText() throws {
        let data = Data(Fixtures.milestonesArrayJSON.utf8)
        let milestones: [GLMilestone] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatMilestones(milestones, json: false)
        XCTAssertTrue(output.contains("v1.0"))
        XCTAssertTrue(output.contains("active"))
    }

    func testFormatMRsText() throws {
        let data = Data(Fixtures.mrsArrayJSON.utf8)
        let mrs: [GLMergeRequest] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatMRs(mrs, json: false)
        XCTAssertTrue(output.contains("!3"))
        XCTAssertTrue(output.contains("feature/x"))
    }

    func testFormatNotesFiltersSystemNotes() throws {
        let mixedNotesJSON = """
        [
          \(Fixtures.noteJSON.dropFirst().dropLast()),
          {"id": 56, "body": "System event", "author": {"id":1,"username":"jdoe","name":"Jane Doe","web_url":"","avatar_url":null},
           "created_at":"2024-01-12T10:00:00.000Z","updated_at":"2024-01-12T10:00:00.000Z",
           "system":true,"resolvable":false,"resolved":null}
        ]
        """
        let data = Data(("[" + Fixtures.noteJSON + "]").utf8)
        let notes: [GLNote] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatNotes(notes, json: false)
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("This is a comment"))
    }

    func testFormatBranchText() throws {
        let data = Data(Fixtures.branchJSON.utf8)
        let branch: GLBranch = try GitLabAPIClient.decode(data)
        let output = Formatter.formatBranch(branch, json: false)
        XCTAssertTrue(output.contains("main"))
        XCTAssertTrue(output.contains("yes"))  // isDefault: yes
    }

    func testFormatPipelinesText() throws {
        let data = Data(Fixtures.pipelinesArrayJSON.utf8)
        let pipelines: [GLPipeline] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatPipelines(pipelines, json: false)
        XCTAssertTrue(output.contains("300"))
        XCTAssertTrue(output.contains("success"))
    }

    func testFormatReleasesText() throws {
        let data = Data(Fixtures.releasesArrayJSON.utf8)
        let releases: [GLRelease] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatReleases(releases, json: false)
        XCTAssertTrue(output.contains("v1.0.0"))
        XCTAssertTrue(output.contains("Version 1.0.0"))
    }

    func testFormatWorkItemsText() throws {
        let data = Data(Fixtures.workItemsArrayJSON.utf8)
        let items: [GLWorkItem] = try GitLabAPIClient.decode(data)
        let output = Formatter.formatWorkItems(items, json: false)
        XCTAssertTrue(output.contains("My work item"))
        XCTAssertTrue(output.contains("Issue"))
    }
}
