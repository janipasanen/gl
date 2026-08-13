import Foundation
import GitLabCore

// MARK: - JSON fixture strings (snake_case, as GitLab sends them)

enum Fixtures {

    static let userJSON = """
    {
      "id": 1,
      "username": "jdoe",
      "name": "Jane Doe",
      "state": "active",
      "email": "jdoe@example.com",
      "web_url": "https://gitlab.example.com/jdoe",
      "avatar_url": null,
      "bio": "Engineer",
      "location": "Helsinki",
      "public_email": null,
      "created_at": "2023-01-15T10:00:00.000Z"
    }
    """

    static let projectJSON = """
    {
      "id": 42,
      "name": "My Project",
      "name_with_namespace": "MyGroup / My Project",
      "path_with_namespace": "mygroup/my-project",
      "description": "A test project",
      "visibility": "private",
      "web_url": "https://gitlab.example.com/mygroup/my-project",
      "default_branch": "main",
      "star_count": 3,
      "forks_count": 1,
      "open_issues_count": 5,
      "created_at": "2023-01-01T00:00:00.000Z",
      "last_activity_at": "2024-05-01T12:00:00.000Z"
    }
    """

    static let issueJSON = """
    {
      "id": 100,
      "iid": 1,
      "project_id": 42,
      "title": "Fix the bug",
      "description": "Something is broken",
      "state": "opened",
      "labels": ["bug", "high"],
      "milestone": {
        "id": 10,
        "iid": 1,
        "title": "v1.0",
        "state": "active"
      },
      "assignees": [
        {"id": 2, "username": "asmith", "name": "Alice Smith", "web_url": "https://gitlab.example.com/asmith", "avatar_url": null}
      ],
      "author": {"id": 1, "username": "jdoe", "name": "Jane Doe", "web_url": "https://gitlab.example.com/jdoe", "avatar_url": null},
      "created_at": "2024-01-10T08:00:00.000Z",
      "updated_at": "2024-01-11T09:00:00.000Z",
      "closed_at": null,
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/issues/1",
      "upvotes": 2,
      "downvotes": 0,
      "user_notes_count": 3,
      "due_date": "2024-02-01",
      "weight": 5,
      "time_stats": {
        "time_estimate": 3600,
        "total_time_spent": 1800,
        "human_time_estimate": "1h",
        "human_total_time_spent": "30m"
      }
    }
    """

    static let milestoneJSON = """
    {
      "id": 10,
      "iid": 1,
      "project_id": 42,
      "group_id": null,
      "title": "v1.0",
      "description": "First release",
      "state": "active",
      "created_at": "2023-12-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z",
      "due_date": "2024-03-31",
      "start_date": "2024-01-01",
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/milestones/1",
      "expired": false
    }
    """

    static let noteJSON = """
    {
      "id": 55,
      "body": "This is a comment",
      "author": {"id": 1, "username": "jdoe", "name": "Jane Doe", "web_url": "https://gitlab.example.com/jdoe", "avatar_url": null},
      "created_at": "2024-01-12T10:00:00.000Z",
      "updated_at": "2024-01-12T10:00:00.000Z",
      "system": false,
      "resolvable": false,
      "resolved": null
    }
    """

    static let mrJSON = """
    {
      "id": 200,
      "iid": 3,
      "project_id": 42,
      "title": "Add feature X",
      "description": "This adds feature X",
      "state": "opened",
      "source_branch": "feature/x",
      "target_branch": "main",
      "author": {"id": 1, "username": "jdoe", "name": "Jane Doe", "web_url": "https://gitlab.example.com/jdoe", "avatar_url": null},
      "assignees": [],
      "labels": ["feature"],
      "milestone": null,
      "created_at": "2024-02-01T08:00:00.000Z",
      "updated_at": "2024-02-02T10:00:00.000Z",
      "merged_at": null,
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/merge_requests/3",
      "upvotes": 1,
      "downvotes": 0,
      "user_notes_count": 0,
      "merge_status": "can_be_merged",
      "draft": false
    }
    """

    static let labelJSON = """
    {
      "id": 7,
      "name": "bug",
      "color": "#d9534f",
      "description": "Something broken",
      "open_issues_count": 4,
      "closed_issues_count": 2,
      "open_merge_requests_count": 0,
      "subscribed": false,
      "priority": null,
      "is_project_label": true
    }
    """

    static let groupJSON = """
    {
      "id": 5,
      "name": "My Group",
      "path": "mygroup",
      "full_name": "My Group",
      "full_path": "mygroup",
      "description": "A test group",
      "visibility": "private",
      "web_url": "https://gitlab.example.com/groups/mygroup",
      "avatar_url": null
    }
    """

    static let memberJSON = """
    {
      "id": 2,
      "username": "asmith",
      "name": "Alice Smith",
      "state": "active",
      "web_url": "https://gitlab.example.com/asmith",
      "avatar_url": null,
      "access_level": 30,
      "expires_at": null
    }
    """

    static let branchJSON = """
    {
      "name": "main",
      "merged": false,
      "protected": true,
      "default": true,
      "can_push": false,
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/tree/main",
      "commit": {
        "id": "abc123def456",
        "short_id": "abc123de",
        "title": "Initial commit",
        "author_name": "Jane Doe",
        "author_email": "jdoe@example.com",
        "authored_date": "2024-01-01T00:00:00.000Z",
        "committer_name": "Jane Doe",
        "committer_email": "jdoe@example.com",
        "committed_date": "2024-01-01T00:00:00.000Z",
        "message": "Initial commit",
        "web_url": "https://gitlab.example.com/mygroup/my-project/-/commit/abc123def456"
      }
    }
    """

    static let pipelineJSON = """
    {
      "id": 300,
      "iid": 1,
      "project_id": 42,
      "sha": "abc123def456789",
      "ref": "main",
      "status": "success",
      "source": "push",
      "created_at": "2024-03-01T10:00:00.000Z",
      "updated_at": "2024-03-01T10:05:00.000Z",
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/pipelines/300"
    }
    """

    // A finished, failed job. Carries fields `gl` does not model (project_id,
    // tag_list, runner, commit) to prove unknown keys are ignored.
    static let jobFailedJSON = """
    {
      "id": 4001,
      "name": "tests",
      "stage": "test",
      "status": "failed",
      "ref": "develop",
      "allow_failure": false,
      "duration": 63.788263,
      "queued_duration": 2.1,
      "failure_reason": "script_failure",
      "created_at": "2024-03-01T10:00:00.000Z",
      "started_at": "2024-03-01T10:00:05.000Z",
      "finished_at": "2024-03-01T10:01:08.000Z",
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/jobs/4001",
      "project_id": 42,
      "tag_list": ["docker"],
      "runner": {"id": 9, "description": "shared-runner", "active": true},
      "user": {"id": 1, "username": "jdoe", "name": "Jane Doe", "web_url": "https://gitlab.example.com/jdoe", "avatar_url": null},
      "pipeline": {
        "id": 300,
        "project_id": 42,
        "ref": "develop",
        "sha": "abc123def456789",
        "status": "failed",
        "web_url": "https://gitlab.example.com/mygroup/my-project/-/pipelines/300"
      },
      "artifacts_file": {"filename": "artifacts.zip", "size": 1024},
      "commit": {
        "id": "abc123def456789",
        "short_id": "abc123de",
        "title": "Fix the thing",
        "author_name": "Jane Doe",
        "author_email": "jdoe@example.com",
        "message": "Fix the thing"
      }
    }
    """

    // A job that has not finished: duration / finished_at / user / artifacts are
    // null or missing, which must not break decoding.
    static let jobRunningJSON = """
    {
      "id": 4002,
      "name": "security",
      "stage": "verify",
      "status": "running",
      "ref": "main",
      "allow_failure": false,
      "duration": null,
      "queued_duration": null,
      "failure_reason": null,
      "created_at": "2024-03-01T10:00:00.000Z",
      "started_at": "2024-03-01T10:00:07.000Z",
      "finished_at": null,
      "user": null,
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/jobs/4002",
      "pipeline": {"id": 300, "ref": "main", "sha": "abc123def456789", "status": "running"}
    }
    """

    /// A raw job log shaped exactly like the ones GitLab returns: ANSI colour
    /// and erase escapes, `section_start` / `section_end` fold markers followed
    /// by `\r`, per-line RFC3339 timestamps with the four-character stream
    /// marker (`00O ` stdout, `01O `/`01E ` and the `00O+` continuation form),
    /// a blank line, and a progress line redrawn with carriage returns.
    static let jobTraceRawText: String = [
        "2024-03-01T10:00:00.000000Z 00O \u{1B}[0KRunning with gitlab-runner 16.6.0\u{1B}[0;m",
        "2024-03-01T10:00:01.000000Z 00O section_start:1709287200:prepare_executor\r\u{1B}[0K",
        "2024-03-01T10:00:01.100000Z 00O+\u{1B}[0K\u{1B}[36;1mPreparing the \"docker\" executor\u{1B}[0;m\u{1B}[0;m",
        "2024-03-01T10:00:05.123456Z 00O $ npm test",
        "2024-03-01T10:00:06.000000Z 01O ",
        "downloading 10%\rdownloading 55%\rdownloading 100%",
        "2024-03-01T10:00:50.000000Z 01O \u{1B}[31mFAIL src/foo.test.ts\u{1B}[0m",
        "2024-03-01T10:00:51.000000Z 00O section_end:1709287260:prepare_executor\r\u{1B}[0K",
        "\u{1B}[31;1mERROR: Job failed: exit code 1\u{1B}[0;m",
    ].joined(separator: "\n") + "\n"

    /// What `Formatter.cleanJobTrace` must turn `jobTraceRawText` into: the
    /// fold-marker lines gone, everything else readable and in order — blank
    /// line included.
    static let jobTraceCleanText: String = [
        "Running with gitlab-runner 16.6.0",
        "Preparing the \"docker\" executor",
        "$ npm test",
        "",
        "downloading 100%",
        "FAIL src/foo.test.ts",
        "ERROR: Job failed: exit code 1",
    ].joined(separator: "\n") + "\n"

    static let releaseJSON = """
    {
      "tag_name": "v1.0.0",
      "name": "Version 1.0.0",
      "description": "First stable release",
      "created_at": "2024-04-01T12:00:00.000Z",
      "released_at": "2024-04-01T12:00:00.000Z",
      "author": {"id": 1, "username": "jdoe", "name": "Jane Doe", "web_url": "https://gitlab.example.com/jdoe", "avatar_url": null},
      "commit": null
    }
    """

    // GraphQL WorkItem node (camelCase keys, global-ID `id`, string `iid`).
    static let workItemJSON = """
    {
      "id": "gid://gitlab/WorkItem/123",
      "iid": "1",
      "title": "My work item",
      "state": "opened",
      "workItemType": {"id": "gid://gitlab/WorkItems::Type/1", "name": "Issue"},
      "webUrl": "https://gitlab.example.com/mygroup/my-project/-/work_items/1",
      "createdAt": "2024-05-01T08:00:00Z",
      "updatedAt": "2024-05-01T08:00:00Z"
    }
    """

    // GraphQL response envelopes for work items (what /api/graphql returns).
    static var workItemsListEnvelope: String {
        #"{"data":{"project":{"workItems":{"nodes":[\#(workItemJSON)]}}}}"#
    }
    static var workItemGetEnvelope: String {
        #"{"data":{"project":{"workItems":{"nodes":[\#(workItemJSON)]}}}}"#
    }
    static var workItemCreateEnvelope: String {
        #"{"data":{"workItemCreate":{"workItem":\#(workItemJSON),"errors":[]}}}"#
    }
    static var workItemUpdateEnvelope: String {
        #"{"data":{"workItemUpdate":{"workItem":\#(workItemJSON),"errors":[]}}}"#
    }
    static var workItemDeleteEnvelope: String {
        #"{"data":{"workItemDelete":{"errors":[]}}}"#
    }
    static let workItemTypesEnvelope = #"""
    {"data":{"project":{"workItemTypes":{"nodes":[
      {"id":"gid://gitlab/WorkItems::Type/1","name":"Issue"},
      {"id":"gid://gitlab/WorkItems::Type/5","name":"Task"}
    ]}}}}
    """#

    static let snippetJSON = """
    {
      "id": 17,
      "title": "Quick fix",
      "file_name": "fix.swift",
      "description": "A handy snippet",
      "visibility": "private",
      "author": {"id": 2, "username": "asmith", "name": "Alice Smith", "web_url": "https://gitlab.example.com/asmith"},
      "project_id": 42,
      "web_url": "https://gitlab.example.com/mygroup/my-project/-/snippets/17",
      "raw_url": "https://gitlab.example.com/mygroup/my-project/-/snippets/17/raw",
      "created_at": "2024-05-01T08:00:00.000Z",
      "updated_at": "2024-05-01T08:00:00.000Z",
      "files": [{"path": "fix.swift", "raw_url": "https://gitlab.example.com/mygroup/my-project/-/snippets/17/raw/main/fix.swift"}]
    }
    """

    // Convenience: arrays

    static var usersArrayJSON: String { "[\(userJSON)]" }
    static var projectsArrayJSON: String { "[\(projectJSON)]" }
    static var issuesArrayJSON: String { "[\(issueJSON)]" }
    static var milestonesArrayJSON: String { "[\(milestoneJSON)]" }
    static var notesArrayJSON: String { "[\(noteJSON)]" }
    static var mrsArrayJSON: String { "[\(mrJSON)]" }
    static var labelsArrayJSON: String { "[\(labelJSON)]" }
    static var groupsArrayJSON: String { "[\(groupJSON)]" }
    static var membersArrayJSON: String { "[\(memberJSON)]" }
    static var branchesArrayJSON: String { "[\(branchJSON)]" }
    static var pipelinesArrayJSON: String { "[\(pipelineJSON)]" }
    static var jobsArrayJSON: String { "[\(jobFailedJSON),\(jobRunningJSON)]" }
    static var releasesArrayJSON: String { "[\(releaseJSON)]" }
    static var workItemsArrayJSON: String { "[\(workItemJSON)]" }
    static var snippetsArrayJSON: String { "[\(snippetJSON)]" }
}
