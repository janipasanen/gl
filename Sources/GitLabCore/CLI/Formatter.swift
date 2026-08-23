import Foundation

public enum Formatter {

    public static func formatUser(_ user: GLUser, json: Bool) -> String {
        if json {
            return user.prettyJSON()
        }
        var lines = [String]()
        lines.append("ID: \(user.id)")
        lines.append("Name: \(user.name)")
        lines.append("Username: \(user.username)")
        lines.append("State: \(user.state)")
        if let avatarUrl = user.avatarUrl {
            lines.append("Avatar URL: \(avatarUrl)")
        }
        return lines.joined(separator: "\n")
    }

    public static func formatUser(_ user: GLUser, json: Bool, completion: @escaping (String) -> Void) {
        completion(formatUser(user, json: json))
    }

    public static func formatProject(_ project: GLProject, json: Bool) -> String {
        if json {
            return project.prettyJSON()
        }
        var lines = [String]()
        lines.append("ID: \(project.id)")
        lines.append("Name: \(project.name)")
        lines.append("Path: \(project.pathWithNamespace)")
        lines.append("Visibility: \(project.visibility)")
        return lines.joined(separator: "\n")
    }

    public static func formatProject(_ project: GLProject, json: Bool, completion: @escaping (String) -> Void) {
        completion(formatProject(project, json: json))
    }

    public static func formatProjects(_ projects: [GLProject], json: Bool) -> String {
        if json {
            return "[" + projects.map { $0.prettyJSON() }.joined(separator: ", ") + "]"
        }
        let lines = projects.enumerated().map { i, p in
            "\(i+1). \(p.name) (\(p.pathWithNamespace))"
        }
        return lines.joined(separator: "\n")
    }

    public static func formatProjects(_ projects: [GLProject], json: Bool, completion: @escaping (String) -> Void) {
        completion(formatProjects(projects, json: json))
    }

    public static func formatIssue(_ issue: GLIssue, json: Bool) -> String {
        if json {
            return issue.prettyJSON()
        }
        var lines = [String]()
        lines.append("ID: \(issue.id)")
        lines.append("Title: \(issue.title)")
        lines.append("State: \(issue.state)")
        // author is non-optional in the model
        let authorName = issue.author.name.isEmpty ? "unknown" : issue.author.name
        let authorUsername = issue.author.username.isEmpty ? "" : "(\(issue.author.username))"
        lines.append("Author: \(authorName) \(authorUsername)")
        return lines.joined(separator: "\n")
    }

    public static func formatIssue(_ issue: GLIssue, json: Bool, completion: @escaping (String) -> Void) {
        completion(formatIssue(issue, json: json))
    }

    public static func formatIssues(_ issues: [GLIssue], json: Bool) -> String {
        if json {
            return "[" + issues.map { $0.prettyJSON() }.joined(separator: ", ") + "]"
        }
        let lines = issues.enumerated().map { i, issue in
            "\(i+1). \(issue.title) (\(issue.state))"
        }
        return lines.joined(separator: "\n")
    }

    public static func formatIssues(_ issues: [GLIssue], json: Bool, completion: @escaping (String) -> Void) {
        completion(formatIssues(issues, json: json))
    }

    public static func formatMilestone(_ milestone: GLMilestone, json: Bool) -> String {
        if json {
            return milestone.prettyJSON()
        }
        var lines = [String]()
        lines.append("ID: \(milestone.id)")
        lines.append("Title: \(milestone.title ?? "")")
        lines.append("State: \(milestone.state ?? "unknown")")
        return lines.joined(separator: "\n")
    }

    public static func formatMilestone(_ milestone: GLMilestone, json: Bool, completion: @escaping (String) -> Void) {
        completion(formatMilestone(milestone, json: json))
    }

    public static func formatMR(_ mr: GLMergeRequest, json: Bool) -> String {
        if json {
            return mr.prettyJSON()
        }
        var lines = [String]()
        lines.append("ID: \(mr.id)")
        lines.append("Title: \(mr.title)")
        lines.append("State: \(mr.state ?? "unknown")")
        return lines.joined(separator: "\n")
    }

    public static func formatMR(_ mr: GLMergeRequest, json: Bool, completion: @escaping (String) -> Void) {
        completion(formatMR(mr, json: json))
    }

    public static func formatMRs(_ mrs: [GLMergeRequest], json: Bool) -> String {
        if json {
            return "[" + mrs.map { $0.prettyJSON() }.joined(separator: ", ") + "]"
        }
        let lines = mrs.enumerated().map { i, mr in
            "\(i+1). \(mr.title) (\(mr.state ?? "unknown"))"
        }
        return lines.joined(separator: "\n")
    }

    public static func formatMRs(_ mrs: [GLMergeRequest], json: Bool, completion: @escaping (String) -> Void) {
        completion(formatMRs(mrs, json: json))
    }
}

extension Encodable {
    public func prettyJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try String(data: encoder.encode(self), encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}
