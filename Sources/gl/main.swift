import Foundation
import GitLabCore

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let environment = ProcessInfo.processInfo.environment
    let client = try GitLabAPIClient(environment: environment)
    let command = try GLCommand.parse(arguments: arguments)
    let output = try await command.run(client: client)
    if !output.isEmpty {
        FileHandle.standardOutput.write(Data((output + "\n").utf8))
    }
} catch {
    FileHandle.standardError.write(Data(("error: \(error.localizedDescription)\n").utf8))
    exit(1)
}
