import Foundation

// MARK: - Shared references

public struct GLUserRef: Codable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let name: String
    public let webUrl: String?
    public let avatarUrl: String?
}

public struct GLMilestoneRef: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int
    public let title: String
    public let state: String
}

public struct GLCommit: Codable, Sendable {
    public let id: String
    public let shortId: String
    public let title: String
    public let authorName: String
    public let authorEmail: String
    public let authoredDate: Date?
    public let committerName: String?
    public let committerEmail: String?
    public let committedDate: Date?
    public let message: String?
    public let webUrl: String?
}

// MARK: - User

public struct GLUser: Codable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let name: String
    public let state: String
    public let email: String?
    public let webUrl: String
    public let avatarUrl: String?
    public let bio: String?
    public let location: String?
    public let publicEmail: String?
    public let createdAt: Date?
}

// MARK: - Project

public struct GLProject: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let nameWithNamespace: String
    public let pathWithNamespace: String
    public let description: String?
    public let visibility: String
    public let webUrl: String
    public let defaultBranch: String?
    public let starCount: Int
    public let forksCount: Int
    public let openIssuesCount: Int?
    public let createdAt: Date?
    public let lastActivityAt: Date?
}

// MARK: - Issue

public struct GLIssue: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int
    public let projectId: Int
    public let title: String
    public let description: String?
    public let state: String
    public let labels: [String]
    public let milestone: GLMilestoneRef?
    public let assignees: [GLUserRef]
    public let author: GLUserRef
    public let createdAt: Date
    public let updatedAt: Date
    public let closedAt: Date?
    public let webUrl: String
    public let upvotes: Int
    public let downvotes: Int
    public let userNotesCount: Int
    public let dueDate: String?
    public let weight: Int?
    public let timeStats: GLTimeStats?
}

public struct GLTimeStats: Codable, Sendable {
    public let timeEstimate: Int
    public let totalTimeSpent: Int
    public let humanTimeEstimate: String?
    public let humanTotalTimeSpent: String?
}

// MARK: - Issue params

public struct CreateIssueParams: Encodable, Sendable {
    public var title: String
    public var description: String?
    public var milestoneId: Int?
    public var labels: String?
    public var assigneeIds: [Int]?
    public var dueDate: String?
    public var weight: Int?

    public init(
        title: String, description: String? = nil,
        milestoneId: Int? = nil, labels: String? = nil,
        assigneeIds: [Int]? = nil, dueDate: String? = nil,
        weight: Int? = nil
    ) {
        self.title = title; self.description = description
        self.milestoneId = milestoneId; self.labels = labels
        self.assigneeIds = assigneeIds; self.dueDate = dueDate
        self.weight = weight
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(milestoneId, forKey: .milestoneId)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(assigneeIds, forKey: .assigneeIds)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(weight, forKey: .weight)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, milestoneId, labels, assigneeIds, dueDate, weight
    }
}

public struct UpdateIssueParams: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var milestoneId: Int?
    public var labels: String?
    public var addLabels: String?
    public var removeLabels: String?
    public var stateEvent: String?   // "close" | "reopen"
    public var assigneeIds: [Int]?
    public var dueDate: String?
    public var weight: Int?

    public init(
        title: String? = nil, description: String? = nil,
        milestoneId: Int? = nil, labels: String? = nil,
        addLabels: String? = nil, removeLabels: String? = nil,
        stateEvent: String? = nil, assigneeIds: [Int]? = nil,
        dueDate: String? = nil, weight: Int? = nil
    ) {
        self.title = title; self.description = description
        self.milestoneId = milestoneId; self.labels = labels
        self.addLabels = addLabels; self.removeLabels = removeLabels
        self.stateEvent = stateEvent; self.assigneeIds = assigneeIds
        self.dueDate = dueDate; self.weight = weight
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(milestoneId, forKey: .milestoneId)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(addLabels, forKey: .addLabels)
        try c.encodeIfPresent(removeLabels, forKey: .removeLabels)
        try c.encodeIfPresent(stateEvent, forKey: .stateEvent)
        try c.encodeIfPresent(assigneeIds, forKey: .assigneeIds)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(weight, forKey: .weight)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, milestoneId, labels, addLabels, removeLabels
        case stateEvent, assigneeIds, dueDate, weight
    }
}

// MARK: - Note

public struct GLNote: Codable, Sendable, Identifiable {
    public let id: Int
    public let body: String
    public let author: GLUserRef
    public let createdAt: Date
    public let updatedAt: Date
    public let system: Bool
    public let resolvable: Bool
    public let resolved: Bool?
}

public struct CreateNoteParams: Encodable, Sendable {
    public let body: String
    public init(body: String) { self.body = body }
}

public struct UpdateNoteParams: Encodable, Sendable {
    public let body: String
    public init(body: String) { self.body = body }
}

// MARK: - Milestone

public struct GLMilestone: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int
    public let projectId: Int?
    public let groupId: Int?
    public let title: String
    public let description: String?
    public let state: String
    public let createdAt: Date
    public let updatedAt: Date
    public let dueDate: String?
    public let startDate: String?
    public let webUrl: String
    public let expired: Bool?
}

public struct CreateMilestoneParams: Encodable, Sendable {
    public var title: String
    public var description: String?
    public var dueDate: String?
    public var startDate: String?

    public init(title: String, description: String? = nil, dueDate: String? = nil, startDate: String? = nil) {
        self.title = title; self.description = description
        self.dueDate = dueDate; self.startDate = startDate
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(startDate, forKey: .startDate)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, dueDate, startDate
    }
}

public struct UpdateMilestoneParams: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var dueDate: String?
    public var startDate: String?
    public var stateEvent: String?   // "activate" | "close"

    public init(
        title: String? = nil, description: String? = nil,
        dueDate: String? = nil, startDate: String? = nil,
        stateEvent: String? = nil
    ) {
        self.title = title; self.description = description
        self.dueDate = dueDate; self.startDate = startDate
        self.stateEvent = stateEvent
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(stateEvent, forKey: .stateEvent)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, dueDate, startDate, stateEvent
    }
}

// MARK: - Merge Request

public struct GLMergeRequest: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int
    public let projectId: Int
    public let title: String
    public let description: String?
    public let state: String
    public let sourceBranch: String
    public let targetBranch: String
    public let author: GLUserRef
    public let assignees: [GLUserRef]
    public let labels: [String]
    public let milestone: GLMilestoneRef?
    public let createdAt: Date
    public let updatedAt: Date
    public let mergedAt: Date?
    public let webUrl: String
    public let upvotes: Int
    public let downvotes: Int
    public let userNotesCount: Int
    public let mergeStatus: String?
    public let draft: Bool?
}

public struct CreateMRParams: Encodable, Sendable {
    public var sourceBranch: String
    public var targetBranch: String
    public var title: String
    public var description: String?
    public var milestoneId: Int?
    public var labels: String?
    public var assigneeIds: [Int]?
    public var removeSourceBranch: Bool?

    public init(
        sourceBranch: String, targetBranch: String, title: String,
        description: String? = nil, milestoneId: Int? = nil,
        labels: String? = nil, assigneeIds: [Int]? = nil,
        removeSourceBranch: Bool? = nil
    ) {
        self.sourceBranch = sourceBranch; self.targetBranch = targetBranch
        self.title = title; self.description = description
        self.milestoneId = milestoneId; self.labels = labels
        self.assigneeIds = assigneeIds; self.removeSourceBranch = removeSourceBranch
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceBranch, forKey: .sourceBranch)
        try c.encode(targetBranch, forKey: .targetBranch)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(milestoneId, forKey: .milestoneId)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(assigneeIds, forKey: .assigneeIds)
        try c.encodeIfPresent(removeSourceBranch, forKey: .removeSourceBranch)
    }

    enum CodingKeys: String, CodingKey {
        case sourceBranch, targetBranch, title, description, milestoneId, labels, assigneeIds, removeSourceBranch
    }
}

public struct UpdateMRParams: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var targetBranch: String?
    public var milestoneId: Int?
    public var labels: String?
    public var stateEvent: String?   // "close" | "reopen"
    public var assigneeIds: [Int]?

    public init(
        title: String? = nil, description: String? = nil,
        targetBranch: String? = nil, milestoneId: Int? = nil,
        labels: String? = nil, stateEvent: String? = nil,
        assigneeIds: [Int]? = nil
    ) {
        self.title = title; self.description = description
        self.targetBranch = targetBranch; self.milestoneId = milestoneId
        self.labels = labels; self.stateEvent = stateEvent
        self.assigneeIds = assigneeIds
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(targetBranch, forKey: .targetBranch)
        try c.encodeIfPresent(milestoneId, forKey: .milestoneId)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(stateEvent, forKey: .stateEvent)
        try c.encodeIfPresent(assigneeIds, forKey: .assigneeIds)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, targetBranch, milestoneId, labels, stateEvent, assigneeIds
    }
}

public struct MergeMRParams: Encodable, Sendable {
    public var mergeCommitMessage: String?
    public var squash: Bool?
    public var shouldRemoveSourceBranch: Bool?

    public init(mergeCommitMessage: String? = nil, squash: Bool? = nil, shouldRemoveSourceBranch: Bool? = nil) {
        self.mergeCommitMessage = mergeCommitMessage
        self.squash = squash
        self.shouldRemoveSourceBranch = shouldRemoveSourceBranch
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(mergeCommitMessage, forKey: .mergeCommitMessage)
        try c.encodeIfPresent(squash, forKey: .squash)
        try c.encodeIfPresent(shouldRemoveSourceBranch, forKey: .shouldRemoveSourceBranch)
    }

    enum CodingKeys: String, CodingKey {
        case mergeCommitMessage, squash, shouldRemoveSourceBranch
    }
}

// MARK: - Label

public struct GLLabel: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let color: String
    public let description: String?
    public let openIssuesCount: Int?
    public let closedIssuesCount: Int?
    public let openMergeRequestsCount: Int?
    public let subscribed: Bool?
    public let priority: Int?
    public let isProjectLabel: Bool?
}

public struct CreateLabelParams: Encodable, Sendable {
    public var name: String
    public var color: String
    public var description: String?
    public var priority: Int?

    public init(name: String, color: String, description: String? = nil, priority: Int? = nil) {
        self.name = name; self.color = color
        self.description = description; self.priority = priority
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(color, forKey: .color)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(priority, forKey: .priority)
    }

    enum CodingKeys: String, CodingKey { case name, color, description, priority }
}

public struct UpdateLabelParams: Encodable, Sendable {
    public var newName: String?
    public var color: String?
    public var description: String?
    public var priority: Int?

    public init(newName: String? = nil, color: String? = nil, description: String? = nil, priority: Int? = nil) {
        self.newName = newName; self.color = color
        self.description = description; self.priority = priority
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(newName, forKey: .newName)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(priority, forKey: .priority)
    }

    enum CodingKeys: String, CodingKey { case newName, color, description, priority }
}

// MARK: - Group

public struct GLGroup: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let path: String
    public let fullName: String
    public let fullPath: String
    public let description: String?
    public let visibility: String
    public let webUrl: String
    public let avatarUrl: String?
}

// MARK: - Member

public struct GLMember: Codable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let name: String
    public let state: String
    public let webUrl: String?
    public let avatarUrl: String?
    public let accessLevel: Int
    public let expiresAt: String?
}

public struct AddMemberParams: Encodable, Sendable {
    public var userId: Int
    public var accessLevel: Int
    public var expiresAt: String?

    public init(userId: Int, accessLevel: Int, expiresAt: String? = nil) {
        self.userId = userId; self.accessLevel = accessLevel; self.expiresAt = expiresAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(accessLevel, forKey: .accessLevel)
        try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }

    enum CodingKeys: String, CodingKey { case userId, accessLevel, expiresAt }
}

// MARK: - Branch

public struct GLBranch: Codable, Sendable {
    public let name: String
    public let merged: Bool
    public let protected: Bool
    public let isDefault: Bool
    public let canPush: Bool?
    public let webUrl: String
    public let commit: GLCommit?

    public enum CodingKeys: String, CodingKey {
        case name, merged, protected, canPush, webUrl, commit
        case isDefault = "default"
    }
}

public struct CreateBranchParams: Encodable, Sendable {
    public let branch: String
    public let ref: String
    public init(branch: String, ref: String) { self.branch = branch; self.ref = ref }
}

// MARK: - Pipeline

public struct GLPipeline: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int?
    public let projectId: Int?
    public let sha: String
    public let ref: String
    public let status: String
    public let source: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let webUrl: String
}

// MARK: - Release

public struct GLRelease: Codable, Sendable {
    public let tagName: String
    public let name: String
    public let description: String?
    public let createdAt: Date
    public let releasedAt: Date?
    public let author: GLUserRef?
    public let commit: GLCommit?
}

public struct CreateReleaseParams: Encodable, Sendable {
    public var tagName: String
    public var name: String
    public var description: String?
    public var ref: String?
    public var releasedAt: String?

    public init(tagName: String, name: String, description: String? = nil, ref: String? = nil, releasedAt: String? = nil) {
        self.tagName = tagName; self.name = name
        self.description = description; self.ref = ref; self.releasedAt = releasedAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tagName, forKey: .tagName)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(ref, forKey: .ref)
        try c.encodeIfPresent(releasedAt, forKey: .releasedAt)
    }

    enum CodingKeys: String, CodingKey { case tagName, name, description, ref, releasedAt }
}

// MARK: - Tag

public struct GLTag: Codable, Sendable {
    public let name: String
    public let message: String?
    public let target: String
    public let commit: GLCommit?
    public let release: GLTagRelease?
}

public struct GLTagRelease: Codable, Sendable {
    public let tagName: String
    public let description: String?
}

public struct CreateTagParams: Encodable, Sendable {
    public var tagName: String
    public var ref: String
    public var message: String?

    public init(tagName: String, ref: String, message: String? = nil) {
        self.tagName = tagName; self.ref = ref; self.message = message
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tagName, forKey: .tagName)
        try c.encode(ref, forKey: .ref)
        try c.encodeIfPresent(message, forKey: .message)
    }

    enum CodingKeys: String, CodingKey { case tagName, ref, message }
}

// MARK: - Work Item

public struct GLWorkItem: Codable, Sendable {
    public let id: Int?
    public let iid: Int
    public let title: String
    public let state: String?
    public let workItemType: GLWorkItemType?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let webUrl: String?
}

public struct GLWorkItemType: Codable, Sendable {
    public let id: String?
    public let name: String
}

public struct CreateWorkItemParams: Encodable, Sendable {
    public var title: String
    public var workItemTypeId: String?
    public var description: String?

    public init(title: String, workItemTypeId: String? = nil, description: String? = nil) {
        self.title = title; self.workItemTypeId = workItemTypeId; self.description = description
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(workItemTypeId, forKey: .workItemTypeId)
        try c.encodeIfPresent(description, forKey: .description)
    }

    enum CodingKeys: String, CodingKey { case title, workItemTypeId, description }
}

public struct UpdateWorkItemParams: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var stateEvent: String?

    public init(title: String? = nil, description: String? = nil, stateEvent: String? = nil) {
        self.title = title; self.description = description; self.stateEvent = stateEvent
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(stateEvent, forKey: .stateEvent)
    }

    enum CodingKeys: String, CodingKey { case title, description, stateEvent }
}

public struct GLWorkItemsResponse: Codable, Sendable {
    public let workItems: [GLWorkItem]?

    enum CodingKeys: String, CodingKey {
        case workItems = "work_items"
    }
}

// MARK: - Access levels

public enum GLAccessLevel: Int, Sendable, CustomStringConvertible {
    case noAccess = 0
    case minimal = 5
    case guest = 10
    case reporter = 20
    case developer = 30
    case maintainer = 40
    case owner = 50

    public var description: String {
        switch self {
        case .noAccess: return "No Access"
        case .minimal: return "Minimal"
        case .guest: return "Guest"
        case .reporter: return "Reporter"
        case .developer: return "Developer"
        case .maintainer: return "Maintainer"
        case .owner: return "Owner"
        }
    }

    public static func name(for level: Int) -> String {
        GLAccessLevel(rawValue: level)?.description ?? "\(level)"
    }
}
