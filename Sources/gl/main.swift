import Foundation
import GitLabCore

let arguments = Array(CommandLine.arguments.dropFirst())

// Help must work without any GitLab credentials configured, so handle it
// before constructing the client (which requires GITLAB_API_URL / a token).
if GLCommand.isHelpRequest(arguments) {
    FileHandle.standardOutput.write(Data((GLCommand.helpText + "\n").utf8))
    exit(0)
}

do {
    let environment = ProcessInfo.processInfo.environment
    let client = try GitLabAPIClient(environment: environment)
    let command = try GLCommand.parse(arguments: arguments)
    
    // Use completion handler style for Swift 5.3 compatibility
    var output: String?
    command.run(client: client) { result in
        output = result
    }
    
    if let out = output, !out.isEmpty {
        FileHandle.standardOutput.write(Data((out + "\n").utf8))
    }
} catch {
    FileHandle.standardError.write(Data(("error: \(error.localizedDescription)\n").utf8))
    exit(1)
}
