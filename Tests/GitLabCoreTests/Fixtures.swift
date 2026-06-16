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
    static var releasesArrayJSON: String { "[\(releaseJSON)]" }
    static var workItemsArrayJSON: String { "[\(workItemJSON)]" }
    static var snippetsArrayJSON: String { "[\(snippetJSON)]" }
}
