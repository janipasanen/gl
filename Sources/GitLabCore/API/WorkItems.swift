import Foundation

// Work items are GraphQL-only on gitlab.com (the REST /work_items endpoints
// return 404 there), so these operations go through GitLab's GraphQL API.
extension GitLabAPIClient {

    /// The WorkItem node fields requested in every read.
    static let workItemFields = "id iid title state workItemType { id name } webUrl createdAt updatedAt"

    // MARK: Decoding wrappers

    private struct ProjectWorkItems: Decodable {
        let project: Container?
        struct Container: Decodable { let workItems: Nodes }
        struct Nodes: Decodable { let nodes: [GLWorkItem] }
    }

    private struct GroupWorkItems: Decodable {
        let group: Container?
        struct Container: Decodable { let workItems: Nodes }
        struct Nodes: Decodable { let nodes: [GLWorkItem] }
    }

    private struct ProjectWorkItemTypes: Decodable {
        let project: Container?
        struct Container: Decodable { let workItemTypes: Nodes }
        struct Nodes: Decodable { let nodes: [GLWorkItemType] }
    }

    private struct CreatePayload: Decodable {
        let workItemCreate: Inner?
        struct Inner: Decodable { let workItem: GLWorkItem?; let errors: [String] }
    }

    private struct UpdatePayload: Decodable {
        let workItemUpdate: Inner?
        struct Inner: Decodable { let workItem: GLWorkItem?; let errors: [String] }
    }

    private struct DeletePayload: Decodable {
        let workItemDelete: Inner?
        struct Inner: Decodable { let errors: [String] }
    }

    // MARK: Read

    /// List work items for a project. `state` accepts `opened`/`closed` (or the
    /// alias `open`); omit for all.
    public func listWorkItems(project: String, first: Int = 20, state: String? = nil) async throws -> [GLWorkItem] {
        let normalizedState = state == "open" ? "opened" : state
        let stateDecl = normalizedState != nil ? ", $state: WorkItemStateEnum" : ""
        let stateArg = normalizedState != nil ? ", state: $state" : ""
        let query = """
        query($p: ID!, $first: Int\(stateDecl)) {
          project(fullPath: $p) {
            workItems(first: $first, sort: CREATED_DESC\(stateArg)) {
              nodes { \(Self.workItemFields) }
            }
          }
        }
        """
        var variables: [String: Any] = ["p": project, "first": first]
        if let s = normalizedState { variables["state"] = s }
        let result: ProjectWorkItems = try await graphQLDecode(query: query, variables: variables)
        return result.project?.workItems.nodes ?? []
    }

    /// Get a single work item by its project-scoped iid.
    public func getWorkItem(project: String, iid: String) async throws -> GLWorkItem {
        let query = """
        query($p: ID!, $iid: String!) {
          project(fullPath: $p) {
            workItems(iid: $iid) { nodes { \(Self.workItemFields) } }
          }
        }
        """
        let result: ProjectWorkItems = try await graphQLDecode(query: query, variables: ["p": project, "iid": iid])
        guard let item = result.project?.workItems.nodes.first else {
            throw ClientError.graphQLError("work item \(iid) not found in \(project)")
        }
        return item
    }

    /// List the work item types available in a project (id + name), so a valid
    /// `workItemTypeId` can be supplied to `createWorkItem`.
    public func listWorkItemTypes(project: String) async throws -> [GLWorkItemType] {
        let query = """
        query($p: ID!) {
          project(fullPath: $p) { workItemTypes { nodes { id name } } }
        }
        """
        let result: ProjectWorkItemTypes = try await graphQLDecode(query: query, variables: ["p": project])
        return result.project?.workItemTypes.nodes ?? []
    }

    /// Resolve a work item type name (e.g. "Task", "Issue") to its global ID.
    public func resolveWorkItemTypeId(project: String, name: String) async throws -> String {
        let types = try await listWorkItemTypes(project: project)
        guard let match = types.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              let id = match.id else {
            let available = types.map(\.name).joined(separator: ", ")
            throw ClientError.graphQLError("unknown work item type '\(name)'. Available: \(available)")
        }
        return id
    }

    /// List work items for a group.
    public func listGroupWorkItems(group: String, first: Int = 20) async throws -> [GLWorkItem] {
        let query = """
        query($p: ID!, $first: Int) {
          group(fullPath: $p) {
            workItems(first: $first, sort: CREATED_DESC) { nodes { \(Self.workItemFields) } }
          }
        }
        """
        let result: GroupWorkItems = try await graphQLDecode(query: query, variables: ["p": group, "first": first])
        return result.group?.workItems.nodes ?? []
    }

    // MARK: Mutations

    /// Create a work item. `params.workItemTypeId` must be a work item type
    /// global ID (see `listWorkItemTypes`).
    public func createWorkItem(project: String, params: CreateWorkItemParams) async throws -> GLWorkItem {
        guard let typeId = params.workItemTypeId else {
            throw ClientError.graphQLError("a work item type id is required (see `gl workitems types <project>`)")
        }
        var input: [String: Any] = [
            "namespacePath": project,
            "title": params.title,
            "workItemTypeId": typeId,
        ]
        if let d = params.description, !d.isEmpty {
            input["descriptionWidget"] = ["description": d]
        }
        if let a = params.assigneeGlobalIds {
            input["assigneesWidget"] = ["assigneeIds": a]
        }
        if let l = params.labelGlobalIds, !l.isEmpty {
            input["labelsWidget"] = ["labelIds": l]            // create variant
        }
        if let m = params.milestoneGlobalId {
            input["milestoneWidget"] = ["milestoneId": m]
        }
        if let w = params.weight {
            input["weightWidget"] = ["weight": w]
        }
        if let dates = Self.dateWidget(start: params.startDate, due: params.dueDate) {
            input["startAndDueDateWidget"] = dates
        }
        let query = """
        mutation($input: WorkItemCreateInput!) {
          workItemCreate(input: $input) { workItem { \(Self.workItemFields) } errors }
        }
        """
        let payload: CreatePayload = try await graphQLDecode(query: query, variables: ["input": input])
        let inner = payload.workItemCreate
        try Self.throwIfMutationErrors(inner?.errors)
        guard let item = inner?.workItem else {
            throw ClientError.graphQLError("workItemCreate returned no work item")
        }
        return item
    }

    /// Update a work item (title / description / state). The work item is
    /// addressed by iid and resolved to its global ID internally.
    public func updateWorkItem(project: String, iid: String, params: UpdateWorkItemParams) async throws -> GLWorkItem {
        let gid = try await resolveWorkItemGID(project: project, iid: iid)
        var input: [String: Any] = ["id": gid]
        if let t = params.title { input["title"] = t }
        if let d = params.description { input["descriptionWidget"] = ["description": d] }
        if let se = params.stateEvent { input["stateEvent"] = Self.stateEventEnum(se) }
        if let a = params.assigneeGlobalIds { input["assigneesWidget"] = ["assigneeIds": a] }
        var labelsWidget: [String: Any] = [:]
        if let add = params.addLabelGlobalIds, !add.isEmpty { labelsWidget["addLabelIds"] = add }
        if let rem = params.removeLabelGlobalIds, !rem.isEmpty { labelsWidget["removeLabelIds"] = rem }
        if !labelsWidget.isEmpty { input["labelsWidget"] = labelsWidget }   // update variant
        if let m = params.milestoneGlobalId { input["milestoneWidget"] = ["milestoneId": m] }
        if let w = params.weight { input["weightWidget"] = ["weight": w] }
        if let dates = Self.dateWidget(start: params.startDate, due: params.dueDate) {
            input["startAndDueDateWidget"] = dates
        }
        let query = """
        mutation($input: WorkItemUpdateInput!) {
          workItemUpdate(input: $input) { workItem { \(Self.workItemFields) } errors }
        }
        """
        let payload: UpdatePayload = try await graphQLDecode(query: query, variables: ["input": input])
        let inner = payload.workItemUpdate
        try Self.throwIfMutationErrors(inner?.errors)
        guard let item = inner?.workItem else {
            throw ClientError.graphQLError("workItemUpdate returned no work item")
        }
        return item
    }

    /// Close a work item.
    public func closeWorkItem(project: String, iid: String) async throws -> GLWorkItem {
        try await updateWorkItem(project: project, iid: iid, params: UpdateWorkItemParams(stateEvent: "close"))
    }

    /// Reopen a work item.
    public func reopenWorkItem(project: String, iid: String) async throws -> GLWorkItem {
        try await updateWorkItem(project: project, iid: iid, params: UpdateWorkItemParams(stateEvent: "reopen"))
    }

    /// Delete a work item (addressed by iid; resolved to its global ID internally).
    public func deleteWorkItem(project: String, iid: String) async throws {
        let gid = try await resolveWorkItemGID(project: project, iid: iid)
        let query = """
        mutation($input: WorkItemDeleteInput!) {
          workItemDelete(input: $input) { errors }
        }
        """
        let payload: DeletePayload = try await graphQLDecode(query: query, variables: ["input": ["id": gid]])
        try Self.throwIfMutationErrors(payload.workItemDelete?.errors)
    }

    // MARK: Internals

    /// Resolve a work item iid to its global ID (`gid://gitlab/WorkItem/<id>`),
    /// required by the update/delete mutations.
    private func resolveWorkItemGID(project: String, iid: String) async throws -> String {
        let item = try await getWorkItem(project: project, iid: iid)
        guard let gid = item.id else {
            throw ClientError.graphQLError("could not resolve global ID for work item \(iid)")
        }
        return gid
    }

    /// Build a startAndDueDateWidget input (fixed dates) when either is set.
    private static func dateWidget(start: String?, due: String?) -> [String: Any]? {
        guard start != nil || due != nil else { return nil }
        var widget: [String: Any] = ["isFixed": true]
        if let s = start { widget["startDate"] = s }
        if let d = due { widget["dueDate"] = d }
        return widget
    }

    /// Map the CLI's `close`/`reopen` to GitLab's WorkItemStateEvent enum.
    private static func stateEventEnum(_ value: String) -> String {
        switch value.lowercased() {
        case "close", "closed": return "CLOSE"
        case "reopen", "reopened", "open", "opened": return "REOPEN"
        default: return value.uppercased()
        }
    }

    /// Throw if a mutation payload's `errors: [String!]!` is non-empty.
    private static func throwIfMutationErrors(_ errors: [String]?) throws {
        if let errors, !errors.isEmpty {
            throw ClientError.graphQLError(errors.joined(separator: "; "))
        }
    }
}
