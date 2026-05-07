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
            let state = args.option("state")
            let milestone = args.option("milestone")
            let labels = args.option("labels")
            let assignee = args.option("assignee")
            let search = args.option("search")
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatIssues(
                    client.listIssues(project: project, state: state, milestone: milestone,
                                      labels: labels, assignee: assignee, search: search,
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
            return GLCommand { client in
                let params = CreateIssueParams(
                    title: title, description: description,
                    milestoneId: milestoneId, labels: labels,
                    dueDate: dueDate, weight: weight
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
            return GLCommand { client in
                let params = UpdateIssueParams(
                    title: title, description: description,
                    milestoneId: milestoneId, labels: labels,
                    addLabels: addLabels, removeLabels: removeLabels,
                    stateEvent: stateEvent,
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
                return "Issue #\(iid) deleted."
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
                return "Note \(noteId) deleted."
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
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatMilestones(
                    client.listMilestones(project: project, state: state, page: page, perPage: perPage),
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
                return "Milestone \(id) deleted."
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
            let state = args.option("state")
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
            return GLCommand { client in
                let params = CreateMRParams(sourceBranch: source, targetBranch: target, title: title,
                                            description: description, milestoneId: milestoneId, labels: labels)
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
            return GLCommand { client in
                let params = UpdateMRParams(title: title, description: description, targetBranch: targetBranch,
                                            milestoneId: milestoneId, labels: labels, stateEvent: stateEvent)
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
                return "Note \(noteId) deleted."
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
            return GLCommand { client in
                let params = CreateLabelParams(name: name, color: color, description: description)
                return try await Formatter.formatLabel(client.createLabel(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "labels update <project> <id>")
            let id = try requireInt(args.positional(3), name: "label-id")
            let newName = args.option("name")
            let color = args.option("color")
            let description = args.option("description") ?? args.option("desc")
            return GLCommand { client in
                let params = UpdateLabelParams(newName: newName, color: color, description: description)
                return try await Formatter.formatLabel(client.updateLabel(project: project, labelId: id, params: params), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "labels delete <project> <id>")
            let id = try requireInt(args.positional(3), name: "label-id")
            return GLCommand { client in
                try await client.deleteLabel(project: project, labelId: id)
                return "Label \(id) deleted."
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
            return GLCommand { client in
                try await Formatter.formatMilestones(client.listGroupMilestones(group: group, state: state), json: json)
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
                return "Group milestone \(id) deleted."
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
                return "Member \(userId) removed."
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
                return "Branch '\(branch)' deleted."
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
                return "Pipeline \(id) deleted."
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
            let page = args.option("page").flatMap(Int.init) ?? 1
            let perPage = args.option("per-page").flatMap(Int.init) ?? 20
            return GLCommand { client in
                try await Formatter.formatWorkItems(client.listWorkItems(project: project, page: page, perPage: perPage), json: json)
            }
        case "get":
            let project = try require(args.positional(2), usage: "workitems get <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.getWorkItem(project: project, iid: iid), json: json)
            }
        case "create":
            let project = try require(args.positional(2), usage: "workitems create <project> --title <title>")
            let title = try require(args.option("title"), usage: "workitems create ... --title <title>")
            let typeId = args.option("type-id")
            let description = args.option("description") ?? args.option("desc")
            return GLCommand { client in
                let params = CreateWorkItemParams(title: title, workItemTypeId: typeId, description: description)
                return try await Formatter.formatWorkItem(client.createWorkItem(project: project, params: params), json: json)
            }
        case "update":
            let project = try require(args.positional(2), usage: "workitems update <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            let title = args.option("title")
            let description = args.option("description") ?? args.option("desc")
            let stateEvent = args.option("state-event")
            return GLCommand { client in
                let params = UpdateWorkItemParams(title: title, description: description, stateEvent: stateEvent)
                return try await Formatter.formatWorkItem(client.updateWorkItem(project: project, iid: iid, params: params), json: json)
            }
        case "close":
            let project = try require(args.positional(2), usage: "workitems close <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.closeWorkItem(project: project, iid: iid), json: json)
            }
        case "reopen":
            let project = try require(args.positional(2), usage: "workitems reopen <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await Formatter.formatWorkItem(client.reopenWorkItem(project: project, iid: iid), json: json)
            }
        case "delete":
            let project = try require(args.positional(2), usage: "workitems delete <project> <iid>")
            let iid = try requireInt(args.positional(3), name: "iid")
            return GLCommand { client in
                try await client.deleteWorkItem(project: project, iid: iid)
                return "Work item \(iid) deleted."
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
                return "Tag '\(tag)' deleted."
            }
        default:
            throw CommandError.unknownCommand("tags \(sub)")
        }
    }

    // MARK: - Helpers

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

      issues list     <project> [--state open|closed|all] [--milestone <title>]
                                [--labels <l1,l2>] [--assignee <username>] [--search <q>]
                                [--page <n>] [--per-page <n>]
      issues get      <project> <iid>
      issues create   <project> --title <t> [--description <d>] [--labels <l>]
                                [--milestone-id <n>] [--due-date <YYYY-MM-DD>] [--weight <n>]
      issues update   <project> <iid> [--title] [--description] [--labels]
                                [--add-labels] [--remove-labels] [--milestone-id]
                                [--state-event close|reopen] [--due-date] [--weight]
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
      mr update  <project> <iid> [--title] [--description] [--target-branch]
                                 [--labels] [--milestone-id] [--state-event close|reopen]
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
      labels create <project> --name <name> --color <#rrggbb> [--description <d>]
      labels update <project> <id> [--name] [--color] [--description]
      labels delete <project> <id>

      groups list    [--search <q>] [--owned]
      groups get     <id-or-path>
      groups projects  <id-or-path>
      groups subgroups <id-or-path>
      groups members   <id-or-path>
      groups milestones list   <group>
      groups milestones get    <group> <id>
      groups milestones create <group> --title <t>
      groups milestones update <group> <id> [--title] [--state-event]
      groups milestones delete <group> <id>

      members list   <project> [--search <q>]
      members get    <project> <user-id>
      members add    <project> --user <id> --access-level <10|20|30|40|50>
      members update <project> <user-id> --access-level <10|20|30|40|50>
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

      workitems list   <project>
      workitems get    <project> <iid>
      workitems create <project> --title <t> [--type-id <id>] [--description <d>]
      workitems update <project> <iid> [--title <t>] [--description <d>] [--state-event close|reopen]
      workitems close  <project> <iid>
      workitems reopen <project> <iid>
      workitems delete <project> <iid>

      tags list   <project> [--search <q>]
      tags get    <project> <tag>
      tags create <project> --name <tag> --ref <ref> [--message <msg>]
      tags delete <project> <tag>

    ENVIRONMENT
      GITLAB_API_URL   GitLab host, e.g. https://gitlab.com
      GITLAB_TOKEN     Personal access token (scope: api)

    ACCESS LEVELS
      10 Guest  20 Reporter  30 Developer  40 Maintainer  50 Owner
    """
}
