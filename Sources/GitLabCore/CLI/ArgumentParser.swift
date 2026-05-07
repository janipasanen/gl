import Foundation

// MARK: - Parsed arguments

/// The result of parsing a flat array of command-line tokens.
///
/// Tokens are classified as:
/// - **Positional**: everything that does not start with `--`
/// - **Option**: `--key value` pairs (next token must not start with `--`)
/// - **Flag**: `--key` with no following value (boolean switches)
public struct ParsedArgs: Sendable {
    public let positionals: [String]
    public let options: [String: String]
    public let flags: Set<String>

    public init(positionals: [String], options: [String: String], flags: Set<String>) {
        self.positionals = positionals
        self.options = options
        self.flags = flags
    }

    // MARK: Accessors

    /// Returns the value for an option key (without the `--` prefix).
    public func option(_ name: String) -> String? { options[name] }

    /// Returns true when a boolean flag is present.
    public func flag(_ name: String) -> Bool { flags.contains(name) }

    /// Returns the positional argument at the given zero-based index.
    public func positional(_ index: Int) -> String? {
        guard index < positionals.count else { return nil }
        return positionals[index]
    }

    // MARK: Parsing

    public static func parse(_ args: [String]) -> ParsedArgs {
        var positionals: [String] = []
        var options: [String: String] = [:]
        var flags: Set<String> = []

        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--") {
                let key = String(arg.dropFirst(2))
                // Is next token a value (not another flag)?
                if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                    options[key] = args[i + 1]
                    i += 2
                } else {
                    flags.insert(key)
                    i += 1
                }
            } else {
                positionals.append(arg)
                i += 1
            }
        }

        return ParsedArgs(positionals: positionals, options: options, flags: flags)
    }
}

// MARK: - Command errors

public enum CommandError: LocalizedError, Sendable {
    case unknownCommand(String)
    case missingArgument(String)
    case invalidArgument(String, String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand(let cmd):
            return "Unknown command: \(cmd). Run `gl help` for usage."
        case .missingArgument(let usage):
            return "Missing argument. Usage: gl \(usage)"
        case .invalidArgument(let name, let reason):
            return "Invalid value for \(name): \(reason)"
        }
    }
}
