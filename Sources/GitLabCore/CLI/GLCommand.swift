import Foundation

// MARK: - Command router

public struct GLCommand: Sendable {

    // MARK: Parse entry point

    /// Parse raw CLI arguments into a runnable command.
    public static func parse(arguments: [String]) throws -> GLCommand {
        // Check for help before any other parsing so --help and -h always work
        if arguments.contains("-h") || arguments.contains("--help") || arguments.contains("help") {
            return GLCommand { _ in Self.helpText }
        }

        let args = ParsedArgs.parse(arguments)
        let json = args.flag("json")

        guard let resource = args.positional(0) else {
            return GLCommand { client in try await Formatter.formatUser(client.currentUser(), json: json) }
        }

        switch resource {
        // ------------------------------------------------------------------ whoami
        case "whoami":
            return GLCommand { client in try await Formatter.formatUser(client.currentUser(), json: json) }

        // ------------------------------------------------------------------ project (legacy shorthand)
        case "project":
            let path = try require(args.positional(1), usage: "project <path>")
            return GLCommand { client in
                try await Formatter.formatProject(client.getProject(path: path), json: json)
            }

        // ------------------------------------------------------------------ projects
        case "projects":
            return try parseProjects(args: args, json: json)

        // ------------------------------------------------------------------ issues
        case "issues":
            return try parseIssues(args: args, json: json)

        // ------------------------------------------------------------------ milestones
        case "milestones":
            return try parseMilestones(args: args, json: json)

        // ------------------------------------------------------------------ mr / merge-requests
        case "mr", "merge-requests":
            return try parseMR(args: args, json: json)

        // ------------------------------------------------------------------ labels
        case "labels":
            return try parseLabels(args: args, json: json)

        // ------------------------------------------------------------------ groups
        case "groups":
            return try parseGroups(args: args, json: json)

        // ------------------------------------------------------------------ members
        case "members":
            return try parseMembers(args: args, json: json)

        // ------------------------------------------------------------------ branches
        case "branches":
            return try parseBranches(args: args, json: json)

        // ------------------------------------------------------------------ pipelines
        case "pipelines":
            return try parsePipelines(args: args, json: json)

        // ------------------------------------------------------------------ releases
        case "releases":
            return try parseReleases(args: args, json: json)

        // ------------------------------------------------------------------ workitems
        case "workitems", "work-items":
            return try parseWorkItems(args: args, json: json)

        // ------------------------------------------------------------------ tags
        case "tags":
            return try parseTags(args: args, json: json)

        // ------------------------------------------------------------------ snippets
        case "snippets":
            return try parseSnippets(args: args, json: json)

        // ------------------------------------------------------------------ graphql
        case "graphql", "gql":
            return try parseGraphQL(args: args)

        default:
            throw CommandError.unknownCommand(resource)
        }
    }

    // MARK: Run

    private let _run: @Sendable (GitLabAPIClient) async throws -> String

    init(run: @escaping @Sendable (GitLabAPIClient) async throws -> String) {
        _run = run
    }

    public func run(client: GitLabAPIClient) async throws -> String {
        try await _run(client)
    }

    // MARK: - Sub-parsers

    private static func parseProjects(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let search = args.option("search")
            let membership = args.flag("membership")
            let owned = args.flag("owned")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatProjects(
                    client.listProjects(search: search, membership: membership, owned: owned, page: page, perPage: perPage),
                    json: json
                )
            }
        case "get":
            let path = try require(args.positional(2), usage: "projects get <path>")
            return GLCommand { client in
                try await Formatter.formatProject(client.getProject(path: path), json: json)
            }
        case "search":
            let query = try require(args.positional(2), usage: "projects search <query>")
            return GLCommand { client in
                try await Formatter.formatProjects(
                    client.listProjects(search: query),
                    json: json
                )
            }
        default:
            throw CommandError.unknownCommand("projects \(sub)")
        }
    }

    private static func parseIssues(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"

        // issues notes <...> (nested)
        if sub == "notes" {
            return try parseIssueNotes(args: args, json: json)
        }

        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "issues list <project>")
            let state = normalizeOpenState(args.option("state"))
            let milestone = args.option("milestone")
            let labels = args.option("labels")
            let assigneeId = args.option("assignee-id").flatMap(Int.init)
            let assigneeUsername = args.option("assignee") ?? args.option("assignee-username")
            let search = args.option("search")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatIssues(
                    client.listIssues(project: project, state: state, milestone: milestone,
                                      labels: labels, assigneeId: assigneeId, assigneeUsername: assigneeUsername, search: search,
                                      page: page, perPage: perPage),
                    json: json
                )
            }

        case "get":
            let project = try require(args.positional(2), usage: "issues get <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatIssue(client.getIssue(project: project, iid: iid), json: json)
            }

        case "create":
            let project = try require(args.positional(2), usage: "issues create <project> --title <title>")
            let title = try require(args.option("title"), usage: "issues create <project> --title <title>")
            let description = args.option("description") ?? args.option("desc")
            let labels = args.option("labels")
            let milestoneId = args.option("milestone-id").flatMap(Int.init)
            let dueDate = args.option("due-date")
            let weight = args.option("weight").flatMap(Int.init)
            let assigneeIdsOpt = args.option("assignee-ids")
            let assigneeNamesOpt = args.option("assignee")
            return GLCommand { client in
                let assigneeIds = try await resolveAssigneeIDs(client: client, assigneeIds: assigneeIdsOpt, assignees: assigneeNamesOpt)
                let params = CreateIssueParams(
                    title: title, description: description,
                    milestoneId: milestoneId, labels: labels,
                    assigneeIds: assigneeIds, dueDate: dueDate, weight: weight
                )
                return try await Formatter.formatIssue(client.createIssue(project: project, params: params), json: json)
            }

        case "update":
            let project = try require(args.positional(2), usage: "issues update <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let labels = args.option("labels")
            let addLabels = args.option("add-labels")
            let removeLabels = args.option("remove-labels")
            let stateEvent = args.option("state-event")
            let milestoneId = args.option("milestone-id").flatMap(Int.init)
            let dueDate = args.option("due-date")
            let weight = args.option("weight").flatMap(Int.init)
            let assigneeIdsOpt = args.option("assignee-ids")
            let assigneeNamesOpt = args.option("assignee")
            return GLCommand { client in
                let assigneeIds = try await resolveAssigneeIDs(client: client, assigneeIds: assigneeIdsOpt, assignees: assigneeNamesOpt)
                let params = UpdateIssueParams(
                    title: title, description: description,
                    milestoneId: milestoneId, labels: labels,
                    addLabels: addLabels, removeLabels: removeLabels,
                    stateEvent: stateEvent, assigneeIds: assigneeIds,
                    dueDate: dueDate, weight: weight
                )
                return try await Formatter.formatIssue(client.updateIssue(project: project, iid: iid, params: params), json: json)
            }

        case "close":
            let project = try require(args.positional(2), usage: "issues close <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatIssue(client.closeIssue(project: project, iid: iid), json: json)
            }

        case "reopen":
            let project = try require(args.positional(2), usage: "issues reopen <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatIssue(client.reopenIssue(project: project, iid: iid), json: json)
            }

        case "delete":
            let project = try require(args.positional(2), usage: "issues delete <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await client.deleteIssue(project: project, iid: iid)
                return Formatter.actionResult("Issue #\(iid) deleted.", json: json, action: "deleted", resource: "issue", id: "\(iid)")
            }

        case "move":
            let project = try require(args.positional(2), usage: "issues move <project> <iid> --to-project-id <id>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let toId = try requireInt(args.option("to-project-id"), name: "--to-project-id")
            return GLCommand { client in
                try await Formatter.formatIssue(client.moveIssue(project: project, iid: iid, toProjectId: toId), json: json)
            }

        case "subscribe":
            let project = try require(args.positional(2), usage: "issues subscribe <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatIssue(client.subscribeToIssue(project: project, iid: iid), json: json)
            }

        case "unsubscribe":
            let project = try require(args.positional(2), usage: "issues unsubscribe <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatIssue(client.unsubscribeFromIssue(project: project, iid: iid), json: json)
            }

        case "time-estimate":
            let project = try require(args.positional(2), usage: "issues time-estimate <project> <iid> --duration <e.g. 3h30m>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let duration = try require(args.option("duration"), usage: "issues time-estimate ... --duration <value>")
            return GLCommand { client in
                let stats = try await client.setIssueTimeEstimate(project: project, iid: iid, duration: duration)
                return json ? stats.prettyJSON() : "Time estimate set: \(stats.humanTimeEstimate ?? duration)"
            }

        case "time-spent":
            let project = try require(args.positional(2), usage: "issues time-spent <project> <iid> --duration <e.g. 1h>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let duration = try require(args.option("duration"), usage: "issues time-spent ... --duration <value>")
            return GLCommand { client in
                let stats = try await client.addIssueTimeSpent(project: project, iid: iid, duration: duration)
                return json ? stats.prettyJSON() : "Time logged: \(stats.humanTotalTimeSpent ?? duration)"
            }

        default:
            throw CommandError.unknownCommand("issues \(sub)")
        }
    }

    private static func parseIssueNotes(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(2) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(3), usage: "issues notes list <project> <iid>")
            let iid = try requireInt(args.positional(4), name: "iid")
            return GLCommand { client in
                try await Formatter.formatNotes(client.listIssueNotes(project: project, issueIid: iid), json: json)
            }
        case "get":
            let project = try require(args.positional(3), usage: "issues notes get <project> <iid> <note-id>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let noteId = try requireInt(args.positional(5), name: "note-id")
            return GLCommand { client in
                try await Formatter.formatNote(client.getIssueNote(project: project, issueIid: iid, noteId: noteId), json: json)
            }
        case "create":
            let project = try require(args.positional(3), usage: "issues notes create <project> <iid> --body <text>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let body = try require(args.option("body"), usage: "issues notes create ... --body <text>")
            return GLCommand { client in
                try await Formatter.formatNote(client.createIssueNote(project: project, issueIid: iid, body: body), json: json)
            }
        case "update":
            let project = try require(args.positional(3), usage: "issues notes update <project> <iid> <note-id> --body <text>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let noteId = try requireInt(args.positional(5), name: "note-id")
            let body = try require(args.option("body"), usage: "issues notes update ... --body <text>")
            return GLCommand { client in
                try await Formatter.formatNote(client.updateIssueNote(project: project, issueIid: iid, noteId: noteId, body: body), json: json)
            }
        case "delete":
            let project = try require(args.positional(3), usage: "issues notes delete <project> <iid> <note-id>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let noteId = try requireInt(args.positional(5), name: "note-id")
            return GLCommand { client in
                try await client.deleteIssueNote(project: project, issueIid: iid, noteId: noteId)
                return Formatter.actionResult("Note \(noteId) deleted.", json: json, action: "deleted", resource: "issue_note", id: "\(noteId)")
            }
        default:
            throw CommandError.unknownCommand("issues notes \(sub)")
        }
    }

    private static func parseMilestones(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "milestones list <project>")
            let state = args.option("state")
            let title = args.option("title")
            let search = args.option("search")
            let iids = try parseIntCSV(args.option("iids"), optionName: "--iids")
            let updatedBefore = args.option("updated-before")
            let updatedAfter = args.option("updated-after")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatMilestones(
                    client.listMilestones(
                        project: project, state: state, title: title, search: search,
                        iids: iids.isEmpty ? nil : iids, updatedBefore: updatedBefore, updatedAfter: updatedAfter,
                        page: page, perPage: perPage
                    ),
                    json: json
                )
            }
        case "get":
            let project = try require(args.positional(2), usage: "milestones get <project> <id>")
            let id = try requireInt(args.positional(3), name: "milestone-id")
            return GLCommand { client in
                try await Formatter.formatMilestone(client.getMilestone(project: project, milestoneId: id), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "milestones create <project> --title <title>")
            let title = try require(args.option("title"), usage: "milestones create ... --title <title>")
            let description = args.option("description") ?? args.option("desc")
            let dueDate = args.option("due-date")
            let startDate = args.option("start-date")
            return GLCommand { client in
                let params = CreateMilestoneParams(title: title, description: description, dueDate: dueDate, startDate: startDate)
                return try await Formatter.formatMilestone(client.createMilestone(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "milestones update <project> <id>")
            let id = try requireInt(args.positional(3), name: "milestone-id")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let dueDate = args.option("due-date")
            let startDate = args.option("start-date")
            let stateEvent = args.option("state-event")
            return GLCommand { client in
                let params = UpdateMilestoneParams(title: title, description: description, dueDate: dueDate, startDate: startDate, stateEvent: stateEvent)
                return try await Formatter.formatMilestone(client.updateMilestone(project: project, milestoneId: id, params: params), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "milestones delete <project> <id>")
            let id = try requireInt(args.positional(3), name: "milestone-id")
            return GLCommand { client in
                try await client.deleteMilestone(project: project, milestoneId: id)
                return Formatter.actionResult("Milestone \(id) deleted.", json: json, action: "deleted", resource: "milestone", id: "\(id)")
            }
        case "issues":
            let project = try require(args.positional(2), usage: "milestones issues <project> <id>")
            let id = try requireInt(args.positional(3), name: "milestone-id")
            return GLCommand { client in
                try await Formatter.formatIssues(client.listMilestoneIssues(project: project, milestoneId: id), json: json)
            }
        case "merge-requests":
            let project = try require(args.positional(2), usage: "milestones merge-requests <project> <id>")
            let id = try requireInt(args.positional(3), name: "milestone-id")
            return GLCommand { client in
                try await Formatter.formatMRs(client.listMilestoneMRs(project: project, milestoneId: id), json: json)
            }
        default:
            throw CommandError.unknownCommand("milestones \(sub)")
        }
    }

    private static func parseMR(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"

        if sub == "notes" {
            return try parseMRNotes(args: args, json: json)
        }

        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "mr list <project>")
            let state = normalizeOpenState(args.option("state"))
            let sourceBranch = args.option("source-branch")
            let targetBranch = args.option("target-branch")
            let milestone = args.option("milestone")
            let labels = args.option("labels")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatMRs(
                    client.listMergeRequests(project: project, state: state, sourceBranch: sourceBranch,
                                             targetBranch: targetBranch, milestone: milestone, labels: labels,
                                             page: page, perPage: perPage),
                    json: json
                )
            }
        case "get":
            let project = try require(args.positional(2), usage: "mr get <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatMR(client.getMergeRequest(project: project, iid: iid), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "mr create <project> --source <branch> --target <branch> --title <title>")
            let source = try require(args.option("source"), usage: "mr create ... --source <branch>")
            let target = try require(args.option("target"), usage: "mr create ... --target <branch>")
            let title = try require(args.option("title"), usage: "mr create ... --title <title>")
            let description = args.option("description") ?? args.option("desc")
            let labels = args.option("labels")
            let milestoneId = args.option("milestone-id").flatMap(Int.init)
            let assigneeIdsOpt = args.option("assignee-ids")
            let assigneeNamesOpt = args.option("assignee")
            return GLCommand { client in
                let assigneeIds = try await resolveAssigneeIDs(client: client, assigneeIds: assigneeIdsOpt, assignees: assigneeNamesOpt)
                let params = CreateMRParams(sourceBranch: source, targetBranch: target, title: title,
                                            description: description, milestoneId: milestoneId, labels: labels, assigneeIds: assigneeIds)
                return try await Formatter.formatMR(client.createMergeRequest(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "mr update <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let targetBranch = args.option("target-branch")
            let labels = args.option("labels")
            let stateEvent = args.option("state-event")
            let milestoneId = args.option("milestone-id").flatMap(Int.init)
            let assigneeIdsOpt = args.option("assignee-ids")
            let assigneeNamesOpt = args.option("assignee")
            return GLCommand { client in
                let assigneeIds = try await resolveAssigneeIDs(client: client, assigneeIds: assigneeIdsOpt, assignees: assigneeNamesOpt)
                let params = UpdateMRParams(title: title, description: description, targetBranch: targetBranch,
                                            milestoneId: milestoneId, labels: labels, stateEvent: stateEvent, assigneeIds: assigneeIds)
                return try await Formatter.formatMR(client.updateMergeRequest(project: project, iid: iid, params: params), json: json)
            }
        case "merge":
            let project = try require(args.positional(2), usage: "mr merge <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let message = args.option("message")
            let squash = args.flag("squash")
            let removeSource = args.flag("remove-source-branch")
            return GLCommand { client in
                let params = MergeMRParams(mergeCommitMessage: message, squash: squash ? true : nil,
                                           shouldRemoveSourceBranch: removeSource ? true : nil)
                return try await Formatter.formatMR(client.mergeMR(project: project, iid: iid, params: params), json: json)
            }
        case "close":
            let project = try require(args.positional(2), usage: "mr close <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatMR(client.closeMergeRequest(project: project, iid: iid), json: json)
            }
        case "reopen":
            let project = try require(args.positional(2), usage: "mr reopen <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatMR(client.reopenMergeRequest(project: project, iid: iid), json: json)
            }
        case "approve":
            let project = try require(args.positional(2), usage: "mr approve <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatMR(client.approveMR(project: project, iid: iid), json: json)
            }
        case "unapprove":
            let project = try require(args.positional(2), usage: "mr unapprove <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatMR(client.unapproveMR(project: project, iid: iid), json: json)
            }
        default:
            throw CommandError.unknownCommand("mr \(sub)")
        }
    }

    private static func parseMRNotes(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(2) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(3), usage: "mr notes list <project> <iid>")
            let iid = try requireInt(args.positional(4), name: "iid")
            return GLCommand { client in
                try await Formatter.formatNotes(client.listMRNotes(project: project, mrIid: iid), json: json)
            }
        case "create":
            let project = try require(args.positional(3), usage: "mr notes create <project> <iid> --body <text>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let body = try require(args.option("body"), usage: "mr notes create ... --body <text>")
            return GLCommand { client in
                try await Formatter.formatNote(client.createMRNote(project: project, mrIid: iid, body: body), json: json)
            }
        case "update":
            let project = try require(args.positional(3), usage: "mr notes update <project> <iid> <note-id> --body <text>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let noteId = try requireInt(args.positional(5), name: "note-id")
            let body = try require(args.option("body"), usage: "mr notes update ... --body <text>")
            return GLCommand { client in
                try await Formatter.formatNote(client.updateMRNote(project: project, mrIid: iid, noteId: noteId, body: body), json: json)
            }
        case "delete":
            let project = try require(args.positional(3), usage: "mr notes delete <project> <iid> <note-id>")
            let iid = try requireInt(args.positional(4), name: "iid")
            let noteId = try requireInt(args.positional(5), name: "note-id")
            return GLCommand { client in
                try await client.deleteMRNote(project: project, mrIid: iid, noteId: noteId)
                return Formatter.actionResult("Note \(noteId) deleted.", json: json, action: "deleted", resource: "mr_note", id: "\(noteId)")
            }
        default:
            throw CommandError.unknownCommand("mr notes \(sub)")
        }
    }

    private static func parseLabels(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "labels list <project>")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 50
            return GLCommand { client in
                try await Formatter.formatLabels(client.listLabels(project: project, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "labels get <project> <id>")
            let id = try requireInt(args.positional(3), name: "label-id")
            return GLCommand { client in
                try await Formatter.formatLabel(client.getLabel(project: project, labelId: id), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "labels create <project> --name <name> --color <#rgb>")
            let name = try require(args.option("name"), usage: "labels create ... --name <name>")
            let color = try require(args.option("color"), usage: "labels create ... --color <#rrggbb>")
            let description = args.option("description") ?? args.option("desc")
            let priority = args.option("priority").flatMap(Int.init)
            return GLCommand { client in
                let params = CreateLabelParams(name: name, color: color, description: description, priority: priority)
                return try await Formatter.formatLabel(client.createLabel(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "labels update <project> <id>")
            let id = try requireInt(args.positional(3), name: "label-id")
            let newName = args.option("name")
            let color = args.option("color")
            let description = args.option("description") ?? args.option("desc")
            let priority = args.option("priority").flatMap(Int.init)
            return GLCommand { client in
                let params = UpdateLabelParams(newName: newName, color: color, description: description, priority: priority)
                return try await Formatter.formatLabel(client.updateLabel(project: project, labelId: id, params: params), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "labels delete <project> <id>")
            let id = try requireInt(args.positional(3), name: "label-id")
            return GLCommand { client in
                try await client.deleteLabel(project: project, labelId: id)
                return Formatter.actionResult("Label \(id) deleted.", json: json, action: "deleted", resource: "label", id: "\(id)")
            }
        default:
            throw CommandError.unknownCommand("labels \(sub)")
        }
    }

    private static func parseGroups(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let search = args.option("search")
            let owned = args.flag("owned")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatGroups(client.listGroups(search: search, owned: owned, page: page, perPage: perPage), json: json)
            }
        case "get":
            let id = try require(args.positional(2), usage: "groups get <id-or-path>")
            return GLCommand { client in
                try await Formatter.formatGroup(client.getGroup(id: id), json: json)
            }
        case "projects":
            let id = try require(args.positional(2), usage: "groups projects <id-or-path>")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatProjects(client.listGroupProjects(group: id, page: page, perPage: perPage), json: json)
            }
        case "subgroups":
            let id = try require(args.positional(2), usage: "groups subgroups <id-or-path>")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatGroups(client.listSubgroups(group: id, page: page, perPage: perPage), json: json)
            }
        case "milestones":
            return try parseGroupMilestones(args: args, json: json)
        case "members":
            let id = try require(args.positional(2), usage: "groups members <id-or-path>")
            return GLCommand { client in
                try await Formatter.formatMembers(client.listGroupMembers(group: id), json: json)
            }
        default:
            throw CommandError.unknownCommand("groups \(sub)")
        }
    }

    private static func parseGroupMilestones(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(2) ?? "list"
        switch sub {
        case "list":
            let group = try require(args.positional(3), usage: "groups milestones list <group>")
            let state = args.option("state")
            let title = args.option("title")
            let search = args.option("search")
            let iids = try parseIntCSV(args.option("iids"), optionName: "--iids")
            let updatedBefore = args.option("updated-before")
            let updatedAfter = args.option("updated-after")
            return GLCommand { client in
                try await Formatter.formatMilestones(
                    client.listGroupMilestones(
                        group: group, state: state, title: title, search: search,
                        iids: iids.isEmpty ? nil : iids, updatedBefore: updatedBefore, updatedAfter: updatedAfter
                    ),
                    json: json
                )
            }
        case "get":
            let group = try require(args.positional(3), usage: "groups milestones get <group> <id>")
            let id = try requireInt(args.positional(4), name: "milestone-id")
            return GLCommand { client in
                try await Formatter.formatMilestone(client.getGroupMilestone(group: group, milestoneId: id), json: json)
            }
        case "create":
            let group = try require(args.positional(3), usage: "groups milestones create <group> --title <title>")
            let title = try require(args.option("title"), usage: "groups milestones create ... --title <title>")
            let description = args.option("description") ?? args.option("desc")
            let dueDate = args.option("due-date")
            let startDate = args.option("start-date")
            return GLCommand { client in
                let params = CreateMilestoneParams(title: title, description: description, dueDate: dueDate, startDate: startDate)
                return try await Formatter.formatMilestone(client.createGroupMilestone(group: group, params: params), json: json)
            }
        case "update":
            let group = try require(args.positional(3), usage: "groups milestones update <group> <id>")
            let id = try requireInt(args.positional(4), name: "milestone-id")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let dueDate = args.option("due-date")
            let startDate = args.option("start-date")
            let stateEvent = args.option("state-event")
            return GLCommand { client in
                let params = UpdateMilestoneParams(title: title, description: description, dueDate: dueDate, startDate: startDate, stateEvent: stateEvent)
                return try await Formatter.formatMilestone(client.updateGroupMilestone(group: group, milestoneId: id, params: params), json: json)
            }
        case "delete":
            let group = try require(args.positional(3), usage: "groups milestones delete <group> <id>")
            let id = try requireInt(args.positional(4), name: "milestone-id")
            return GLCommand { client in
                try await client.deleteGroupMilestone(group: group, milestoneId: id)
                return Formatter.actionResult("Group milestone \(id) deleted.", json: json, action: "deleted", resource: "group_milestone", id: "\(id)")
            }
        default:
            throw CommandError.unknownCommand("groups milestones \(sub)")
        }
    }

    private static func parseMembers(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "members list <project>")
            let query = args.option("search")
            return GLCommand { client in
                try await Formatter.formatMembers(client.listProjectMembers(project: project, query: query), json: json)
            }
        case "add":
            let project = try require(args.positional(2), usage: "members add <project> --user <id> --access-level <level>")
            let userId = try requireInt(args.option("user"), name: "--user")
            let accessLevel = try requireInt(args.option("access-level"), name: "--access-level")
            let expiresAt = args.option("expires-at")
            return GLCommand { client in
                let params = AddMemberParams(userId: userId, accessLevel: accessLevel, expiresAt: expiresAt)
                return try await Formatter.formatMember(client.addProjectMember(project: project, params: params), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "members get <project> <user-id>")
            let userId = try requireInt(args.positional(3), name: "user-id")
            return GLCommand { client in
                try await Formatter.formatMember(client.getProjectMember(project: project, userId: userId), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "members update <project> <user-id> --access-level <n>")
            let userId = try requireInt(args.positional(3), name: "user-id")
            let accessLevel = try requireInt(args.option("access-level"), name: "--access-level")
            return GLCommand { client in
                try await Formatter.formatMember(client.updateProjectMember(project: project, userId: userId, accessLevel: accessLevel), json: json)
            }
        case "remove":
            let project = try require(args.positional(2), usage: "members remove <project> --user <id>")
            let userId = try requireInt(args.option("user"), name: "--user")
            return GLCommand { client in
                try await client.removeProjectMember(project: project, userId: userId)
                return Formatter.actionResult("Member \(userId) removed.", json: json, action: "removed", resource: "member", id: "\(userId)")
            }
        default:
            throw CommandError.unknownCommand("members \(sub)")
        }
    }

    private static func parseBranches(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "branches list <project>")
            let search = args.option("search")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatBranches(client.listBranches(project: project, search: search, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "branches get <project> <branch>")
            let branch = try require(args.positional(3), usage: "branches get <project> <branch>")
            return GLCommand { client in
                try await Formatter.formatBranch(client.getBranch(project: project, branch: branch), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "branches create <project> --name <branch> --ref <ref>")
            let name = try require(args.option("name"), usage: "branches create ... --name <branch>")
            let ref = try require(args.option("ref"), usage: "branches create ... --ref <ref>")
            return GLCommand { client in
                try await Formatter.formatBranch(client.createBranch(project: project, params: CreateBranchParams(branch: name, ref: ref)), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "branches delete <project> <branch>")
            let branch = try require(args.positional(3), usage: "branches delete <project> <branch>")
            return GLCommand { client in
                try await client.deleteBranch(project: project, branch: branch)
                return Formatter.actionResult("Branch '\(branch)' deleted.", json: json, action: "deleted", resource: "branch", id: branch)
            }
        default:
            throw CommandError.unknownCommand("branches \(sub)")
        }
    }

    private static func parsePipelines(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "pipelines list <project>")
            let ref = args.option("ref")
            let status = args.option("status")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatPipelines(client.listPipelines(project: project, ref: ref, status: status, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "pipelines get <project> <id>")
            let id = try requireInt(args.positional(3), name: "pipeline-id")
            return GLCommand { client in
                try await Formatter.formatPipeline(client.getPipeline(project: project, pipelineId: id), json: json)
            }
        case "cancel":
            let project = try require(args.positional(2), usage: "pipelines cancel <project> <id>")
            let id = try requireInt(args.positional(3), name: "pipeline-id")
            return GLCommand { client in
                try await Formatter.formatPipeline(client.cancelPipeline(project: project, pipelineId: id), json: json)
            }
        case "retry":
            let project = try require(args.positional(2), usage: "pipelines retry <project> <id>")
            let id = try requireInt(args.positional(3), name: "pipeline-id")
            return GLCommand { client in
                try await Formatter.formatPipeline(client.retryPipeline(project: project, pipelineId: id), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "pipelines create <project> --ref <branch>")
            let ref = try require(args.option("ref"), usage: "pipelines create ... --ref <branch>")
            return GLCommand { client in
                try await Formatter.formatPipeline(client.createPipeline(project: project, ref: ref), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "pipelines delete <project> <id>")
            let id = try requireInt(args.positional(3), name: "pipeline-id")
            return GLCommand { client in
                try await client.deletePipeline(project: project, pipelineId: id)
                return Formatter.actionResult("Pipeline \(id) deleted.", json: json, action: "deleted", resource: "pipeline", id: "\(id)")
            }
        default:
            throw CommandError.unknownCommand("pipelines \(sub)")
        }
    }

    private static func parseReleases(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "releases list <project>")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatReleases(client.listReleases(project: project, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "releases get <project> <tag>")
            let tag = try require(args.positional(3), usage: "releases get <project> <tag>")
            return GLCommand { client in
                try await Formatter.formatRelease(client.getRelease(project: project, tagName: tag), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "releases create <project> --tag <tag> --name <name>")
            let tag = try require(args.option("tag"), usage: "releases create ... --tag <tag>")
            let name = try require(args.option("name"), usage: "releases create ... --name <name>")
            let description = args.option("description") ?? args.option("desc")
            let ref = args.option("ref")
            return GLCommand { client in
                let params = CreateReleaseParams(tagName: tag, name: name, description: description, ref: ref)
                return try await Formatter.formatRelease(client.createRelease(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "releases update <project> <tag> --name <name>")
            let tag = try require(args.positional(3), usage: "releases update <project> <tag> --name <name>")
            let name = try require(args.option("name"), usage: "releases update ... --name <name>")
            let description = args.option("description") ?? args.option("desc")
            return GLCommand { client in
                try await Formatter.formatRelease(client.updateRelease(project: project, tagName: tag, name: name, description: description), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "releases delete <project> <tag>")
            let tag = try require(args.positional(3), usage: "releases delete <project> <tag>")
            return GLCommand { client in
                let r = try await client.deleteRelease(project: project, tagName: tag)
                if json { return r.prettyJSON() }
                return "Release '\(r.tagName)' deleted."
            }
        default:
            throw CommandError.unknownCommand("releases \(sub)")
        }
    }

    private static func parseWorkItems(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "workitems list <project>")
            let first = args.option("first").flatMap(Int.init) ?? args.option("per-page").flatMap(Int.init) ?? 20
            let state = normalizeOpenState(args.option("state"))
            return GLCommand { client in
                try await Formatter.formatWorkItems(client.listWorkItems(project: project, first: first, state: state), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "workitems get <project> <iid>")
            let iid = try require(args.positional(3), usage: "workitems get <project> <iid>")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.getWorkItem(project: project, iid: iid), json: json)
            }
        case "types":
            let project = try require(args.positional(2), usage: "workitems types <project>")
            return GLCommand { client in
                try await Formatter.formatWorkItemTypes(client.listWorkItemTypes(project: project), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "workitems create <project> --title <t> (--type-id <gid> | --type <name>)")
            let title = try require(args.option("title"), usage: "workitems create ... --title <title>")
            let explicitTypeId = args.option("type-id")
            let typeName = args.option("type")
            guard explicitTypeId != nil || typeName != nil else {
                throw CommandError.missingArgument("workitems create <project> --title <t> (--type-id <gid> | --type <name>)")
            }
            let description = args.option("description") ?? args.option("desc")
            return GLCommand { client in
                let typeId: String
                if let tid = explicitTypeId {
                    typeId = tid
                } else {
                    typeId = try await client.resolveWorkItemTypeId(project: project, name: typeName!)
                }
                let params = CreateWorkItemParams(title: title, workItemTypeId: typeId, description: description)
                return try await Formatter.formatWorkItem(client.createWorkItem(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "workitems update <project> <iid>")
            let iid = try require(args.positional(3), usage: "workitems update <project> <iid>")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let stateEvent = args.option("state-event")
            return GLCommand { client in
                let params = UpdateWorkItemParams(title: title, description: description, stateEvent: stateEvent)
                return try await Formatter.formatWorkItem(client.updateWorkItem(project: project, iid: iid, params: params), json: json)
            }
        case "close":
            let project = try require(args.positional(2), usage: "workitems close <project> <iid>")
            let iid = try require(args.positional(3), usage: "workitems close <project> <iid>")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.closeWorkItem(project: project, iid: iid), json: json)
            }
        case "reopen":
            let project = try require(args.positional(2), usage: "workitems reopen <project> <iid>")
            let iid = try require(args.positional(3), usage: "workitems reopen <project> <iid>")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.reopenWorkItem(project: project, iid: iid), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "workitems delete <project> <iid>")
            let iid = try require(args.positional(3), usage: "workitems delete <project> <iid>")
            return GLCommand { client in
                try await client.deleteWorkItem(project: project, iid: iid)
                return Formatter.actionResult("Work item \(iid) deleted.", json: json, action: "deleted", resource: "work_item", id: iid)
            }
        default:
            throw CommandError.unknownCommand("workitems \(sub)")
        }
    }

    private static func parseTags(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "tags list <project>")
            let search = args.option("search")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatTags(client.listTags(project: project, search: search, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "tags get <project> <tag>")
            let tag = try require(args.positional(3), usage: "tags get <project> <tag>")
            return GLCommand { client in
                try await Formatter.formatTag(client.getTag(project: project, tagName: tag), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "tags create <project> --name <tag> --ref <ref>")
            let name = try require(args.option("name"), usage: "tags create ... --name <tag>")
            let ref = try require(args.option("ref"), usage: "tags create ... --ref <ref>")
            let message = args.option("message")
            return GLCommand { client in
                let params = CreateTagParams(tagName: name, ref: ref, message: message)
                return try await Formatter.formatTag(client.createTag(project: project, params: params), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "tags delete <project> <tag>")
            let tag = try require(args.positional(3), usage: "tags delete <project> <tag>")
            return GLCommand { client in
                try await client.deleteTag(project: project, tagName: tag)
                return Formatter.actionResult("Tag '\(tag)' deleted.", json: json, action: "deleted", resource: "tag", id: tag)
            }
        default:
            throw CommandError.unknownCommand("tags \(sub)")
        }
    }

    private static func parseSnippets(args: ParsedArgs, json: Bool) throws -> GLCommand {
        let sub = args.positional(1) ?? "list"
        switch sub {
        case "list":
            let project = try require(args.positional(2), usage: "snippets list <project>")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatSnippets(client.listSnippets(project: project, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "snippets get <project> <id>")
            let id = try requireInt(args.positional(3), name: "snippet-id")
            return GLCommand { client in
                try await Formatter.formatSnippet(client.getSnippet(project: project, snippetId: id), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "snippets create <project> --title <t> --file-name <name> --content <text>|--file <path>")
            let title = try require(args.option("title"), usage: "snippets create ... --title <t>")
            // Content may come from --content or be read from a local --file.
            var content = args.option("content")
            var fileName = args.option("file-name")
            if let path = args.option("file") {
                let fileContent = try readFileContent(path)
                if content == nil { content = fileContent }
                if fileName == nil { fileName = (path as NSString).lastPathComponent }
            }
            let resolvedContent = try require(content, usage: "snippets create ... provide --content <text> or --file <path>")
            let resolvedFileName = try require(fileName, usage: "snippets create ... --file-name <name> (or pass --file to derive it)")
            let description = args.option("description") ?? args.option("desc")
            let visibility = args.option("visibility") ?? "private"
            return GLCommand { client in
                let params = CreateSnippetParams(
                    title: title, fileName: resolvedFileName, content: resolvedContent,
                    description: description, visibility: visibility
                )
                return try await Formatter.formatSnippet(client.createSnippet(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "snippets update <project> <id>")
            let id = try requireInt(args.positional(3), name: "snippet-id")
            var content = args.option("content")
            var fileName = args.option("file-name")
            if let path = args.option("file") {
                let fileContent = try readFileContent(path)
                if content == nil { content = fileContent }
                if fileName == nil { fileName = (path as NSString).lastPathComponent }
            }
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let visibility = args.option("visibility")
            let finalContent = content
            let finalFileName = fileName
            return GLCommand { client in
                let params = UpdateSnippetParams(
                    title: title, fileName: finalFileName, content: finalContent,
                    description: description, visibility: visibility
                )
                return try await Formatter.formatSnippet(client.updateSnippet(project: project, snippetId: id, params: params), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "snippets delete <project> <id>")
            let id = try requireInt(args.positional(3), name: "snippet-id")
            return GLCommand { client in
                try await client.deleteSnippet(project: project, snippetId: id)
                return Formatter.actionResult("Snippet \(id) deleted.", json: json, action: "deleted", resource: "snippet", id: "\(id)")
            }
        default:
            throw CommandError.unknownCommand("snippets \(sub)")
        }
    }

    private static func parseGraphQL(args: ParsedArgs) throws -> GLCommand {
        // Query source: --query <q>, --file <path>, a positional, or stdin.
        let query: String
        if let q = args.option("query") {
            query = q
        } else if let path = args.option("file") {
            query = try readFileContent(path)
        } else if let positional = args.positional(1) {
            query = positional
        } else {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            query = String(data: data, encoding: .utf8) ?? ""
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandError.missingArgument("graphql (--query <q> | --file <path> | '<query>' | stdin) [--variables '<json>']")
        }

        // Validate --variables (if any) is a JSON object up front, then pass the
        // raw string through (keeps the closure's captures Sendable).
        let variablesJSON = args.option("variables")
        if let vj = variablesJSON, !vj.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(vj.utf8)), obj is [String: Any] else {
                throw CommandError.invalidArgument("--variables", "must be a JSON object")
            }
        }

        return GLCommand { client in
            let data = try await client.graphQL(query: query, variablesJSON: variablesJSON)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    // MARK: - Helpers

    /// Map the colloquial `open` to GitLab's canonical `opened` for issue and
    /// merge-request state filters. GitLab's API rejects `open` with a 400, so
    /// this lets the documented/intuitive value work while leaving every other
    /// value (`opened`, `closed`, `merged`, `all`, …) untouched.
    private static func normalizeOpenState(_ value: String?) -> String? {
        value == "open" ? "opened" : value
    }

    /// Read the contents of a local file for use as a snippet body.
    private static func readFileContent(_ path: String) throws -> String {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw CommandError.invalidArgument("--file", "could not read file at \(path)")
        }
    }

    private static func require(_ value: String?, usage: String) throws -> String {
        guard let v = value, !v.isEmpty else {
            throw CommandError.missingArgument(usage)
        }
        return v
    }

    private static func requireInt(_ value: String?, name: String) throws -> Int {
        guard let raw = value else {
            throw CommandError.missingArgument("\(name) <integer>")
        }
        guard let n = Int(raw) else {
            throw CommandError.invalidArgument(name, "'\(raw)' is not a valid integer")
        }
        return n
    }

    private static func parseCSV(_ value: String?) -> [String] {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return []
        }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseIntCSV(_ value: String?, optionName: String) throws -> [Int] {
        let values = parseCSV(value)
        guard !values.isEmpty else { return [] }
        return try values.map { raw in
            guard let n = Int(raw) else {
                throw CommandError.invalidArgument(optionName, "'\(raw)' is not a valid integer")
            }
            return n
        }
    }

    private static func resolveAssigneeIDs(
        client: GitLabAPIClient,
        assigneeIds: String? = nil,
        assignees: String? = nil
    ) async throws -> [Int]? {
        var ids = try parseIntCSV(assigneeIds, optionName: "--assignee-ids")
        let usernames = parseCSV(assignees)

        if !usernames.isEmpty {
            for username in usernames {
                let users = try await client.searchUsers(query: username, perPage: 100)
                guard let user = users.first(where: { $0.username == username }) ?? users.first else {
                    throw CommandError.invalidArgument("--assignee", "No user found for '\(username)'")
                }
                ids.append(user.id)
            }
        }

        guard !ids.isEmpty else { return nil }
        return Array(Set(ids)).sorted()
    }

    // MARK: - Help

    public static let helpText = """
    gl — GitLab CLI

    A command-line tool for interacting with GitLab projects, issues, merge
    requests, pipelines, branches, releases, and more via the GitLab REST API.

    USAGE
      gl [--json] <resource> <subcommand> [args...] [options...]
      gl help | --help | -h

    GLOBAL FLAGS
      --json          Output raw JSON instead of formatted text
      --help, -h      Show this help message

    RESOURCES & SUBCOMMANDS

      whoami                                  Show authenticated user
      project <path>                          Show a project

      projects list   [--search <q>] [--membership] [--owned]
      projects get    <path>
      projects search <query>

      issues list     <project> [--state opened|closed|all] [--milestone <title>]
                                [--labels <l1,l2>] [--assignee <username>] [--assignee-id <id>]
                                [--search <q>]
                                [--page <n>] [--per-page <n>]
      issues get      <project> <iid>
      issues create   <project> --title <t> [--description <d>] [--labels <l>]
                                [--milestone-id <n>] [--due-date <YYYY-MM-DD>] [--weight <n>]
                                [--assignee <username>] [--assignee-ids <id1,id2>]
      issues update   <project> <iid> [--title] [--description] [--labels]
                                [--add-labels] [--remove-labels] [--milestone-id]
                                [--state-event close|reopen] [--due-date] [--weight]
                                [--assignee <username>] [--assignee-ids <id1,id2>]
      issues close    <project> <iid>
      issues reopen   <project> <iid>
      issues delete   <project> <iid>
      issues move     <project> <iid> --to-project-id <id>
      issues subscribe   <project> <iid>
      issues unsubscribe <project> <iid>
      issues time-estimate <project> <iid> --duration <e.g. 3h30m>
      issues time-spent   <project> <iid> --duration <e.g. 1h>
      issues notes list   <project> <iid>
      issues notes get    <project> <iid> <note-id>
      issues notes create <project> <iid> --body <text>
      issues notes update <project> <iid> <note-id> --body <text>
      issues notes delete <project> <iid> <note-id>

      milestones list   <project> [--state active|closed|all]
                                   [--title <title>] [--search <q>] [--iids <id1,id2>]
                                   [--updated-before <iso>] [--updated-after <iso>]
      milestones get    <project> <id>
      milestones create <project> --title <t> [--description <d>]
                                   [--due-date <YYYY-MM-DD>] [--start-date <YYYY-MM-DD>]
      milestones update <project> <id> [--title] [--description] [--due-date]
                                        [--start-date] [--state-event activate|close]
      milestones delete         <project> <id>
      milestones issues         <project> <id>
      milestones merge-requests <project> <id>

      mr list    <project> [--state opened|closed|merged|all] [--source-branch]
                           [--target-branch] [--milestone] [--labels]
      mr get     <project> <iid>
      mr create  <project> --source <branch> --target <branch> --title <t>
                           [--description <d>] [--labels] [--milestone-id]
                           [--assignee <username>] [--assignee-ids <id1,id2>]
      mr update  <project> <iid> [--title] [--description] [--target-branch]
                                 [--labels] [--milestone-id] [--state-event close|reopen]
                                 [--assignee <username>] [--assignee-ids <id1,id2>]
      mr merge   <project> <iid> [--message <msg>] [--squash] [--remove-source-branch]
      mr close   <project> <iid>
      mr reopen  <project> <iid>
      mr approve   <project> <iid>
      mr unapprove <project> <iid>
      mr notes list   <project> <iid>
      mr notes create <project> <iid> --body <text>
      mr notes update <project> <iid> <note-id> --body <text>
      mr notes delete <project> <iid> <note-id>

      labels list   <project>
      labels get    <project> <id>
      labels create <project> --name <name> --color <#rrggbb> [--description <d>] [--priority <n>]
      labels update <project> <id> [--name] [--color] [--description] [--priority <n>]
      labels delete <project> <id>

      groups list    [--search <q>] [--owned]
      groups get     <id-or-path>
      groups projects  <id-or-path>
      groups subgroups <id-or-path>
      groups members   <id-or-path>
      groups milestones list   <group>
                              [--state active|closed|all] [--title <t>] [--search <q>]
                              [--iids <id1,id2>] [--updated-before <iso>] [--updated-after <iso>]
      groups milestones get    <group> <id>
      groups milestones create <group> --title <t>
      groups milestones update <group> <id> [--title] [--state-event activate|close]
      groups milestones delete <group> <id>

      members list   <project> [--search <q>]
      members get    <project> <user-id>
      members add    <project> --user <id> --access-level <0|5|10|20|30|40|50>
      members update <project> <user-id> --access-level <0|5|10|20|30|40|50>
      members remove <project> --user <id>

      branches list   <project> [--search <q>]
      branches get    <project> <branch>
      branches create <project> --name <branch> --ref <ref>
      branches delete <project> <branch>

      pipelines list   <project> [--ref <branch>] [--status running|success|failed|...]
      pipelines get    <project> <id>
      pipelines create <project> --ref <branch>
      pipelines cancel <project> <id>
      pipelines retry  <project> <id>
      pipelines delete <project> <id>

      releases list   <project>
      releases get    <project> <tag>
      releases create <project> --tag <tag> --name <name> [--description <d>] [--ref <ref>]
      releases update <project> <tag> --name <name> [--description <d>]
      releases delete <project> <tag>

      workitems list   <project> [--state opened|closed] [--first <n>]   (via GraphQL)
      workitems get    <project> <iid>
      workitems types  <project>                          List type IDs for create
      workitems create <project> --title <t> (--type-id <gid> | --type <name>) [--description <d>]
      workitems update <project> <iid> [--title <t>] [--description <d>] [--state-event close|reopen]
      workitems close  <project> <iid>
      workitems reopen <project> <iid>
      workitems delete <project> <iid>

      tags list   <project> [--search <q>]
      tags get    <project> <tag>
      tags create <project> --name <tag> --ref <ref> [--message <msg>]
      tags delete <project> <tag>

      snippets list   <project>
      snippets get    <project> <id>
      snippets create <project> --title <t> --file-name <name> (--content <text> | --file <path>)
                                [--description <d>] [--visibility private|internal|public]
      snippets update <project> <id> [--title <t>] [--file-name <name>]
                                [--content <text> | --file <path>] [--description <d>]
                                [--visibility private|internal|public]
      snippets delete <project> <id>

      graphql  (--query <q> | --file <path> | '<query>' | stdin) [--variables '<json>']
               Run a raw GraphQL query/mutation against /api/graphql and print the
               data as JSON. Use for APIs not exposed over REST (e.g. work items on
               gitlab.com). Alias: gql.

    ENVIRONMENT
      GITLAB_API_URL        GitLab host, e.g. https://gitlab.com
      GITLAB_TOKEN          Personal access token (scope: api)
      GITLAB_TOKEN_COMMAND  Command whose stdout is the token, used when GITLAB_TOKEN
                            is unset — keeps the token out of env vars and files,
                            e.g. security find-generic-password -s gitlab-gl-token -w

    ACCESS LEVELS
      0 No access  5 Minimal  10 Guest  20 Reporter  30 Developer  40 Maintainer  50 Owner
    """
}
