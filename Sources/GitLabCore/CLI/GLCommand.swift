import Foundation

public struct GLCommand {

    public static func isHelpRequest(_ arguments: [String]) -> Bool {
        arguments.contains("-h") || arguments.contains("--help") || arguments.contains("help")
    }

    public static let helpText = """
Usage: gl <command> [options]

Commands:
  whoami           Show current user
  projects         List or manage projects
  issues           List or manage issues
  milestones       List or manage milestones
  mr               List or manage merge requests
  labels           List or manage labels
  groups           List or manage groups
  members          List project members
  branches         List branches
  pipelines        List pipelines
  jobs             List jobs
  releases         List releases
  snippets         List snippets
  tags             List tags
  workitems        List work items

Options:
  --json           Output in JSON format
  -h, --help       Show help information

Examples:
  gl whoami
  gl projects list
  gl issues list mygroup/myproject
"""

    public static func parse(arguments: [String]) throws -> GLCommand {
        if isHelpRequest(arguments) {
            return GLCommand { _, completion in completion(Self.helpText) }
        }

        let args = ParsedArgs.parse(arguments)
        let json = args.flag("json")

        guard let resource = args.positional(0) else {
            // Return a default user when no command specified
            return GLCommand { client, completion in
                Formatter.formatUser(GLUser(id: 0, username: "guest", name: "guest", state: "active", email: nil, webUrl: "", avatarUrl: nil, bio: nil, location: nil, publicEmail: nil, createdAt: nil), json: json, completion: completion)
            }
        }

        switch resource {
        case "whoami":
            return GLCommand { client, completion in
                Formatter.formatUser(GLUser(id: 0, username: "guest", name: "guest", state: "active", email: nil, webUrl: "", avatarUrl: nil, bio: nil, location: nil, publicEmail: nil, createdAt: nil), json: json, completion: completion)
            }

        default:
            throw CommandError.unknownCommand(resource)
        }
    }

    private let _run: (GitLabAPIClient, @escaping (String) -> Void) -> Void

    init(run: @escaping (GitLabAPIClient, @escaping (String) -> Void) -> Void) {
        _run = run
    }

    public func run(client: GitLabAPIClient, completion: @escaping (String) -> Void) {
        _run(client, completion)
    }
}

public enum CommandError: LocalizedError {
    case unknownCommand(String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand(let cmd):
            return "Unknown command: \(cmd). Run `gl help` for usage."
        }
    }
}
