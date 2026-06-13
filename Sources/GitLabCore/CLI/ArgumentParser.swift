import Foundation

// MARK: - Parsed arguments

/// The result of parsing a flat array of command-line tokens.
///
/// Tokens are classified as:
/// - **Positional**: everything that does not start with `--`
/// - **Option**: `--key value` or `--key=value` pairs
/// - **Flag**: a boolean switch (`--key` with no value)
///
/// Boolean switches are recognised by name (`booleanFlags`) rather than by
/// guessing from the following token. This lets a flag like `--json` appear
/// *anywhere* — before the resource, between subcommand and arguments, or at
/// the end — without swallowing the next positional as its "value".
public struct ParsedArgs: Sendable {
    public let positionals: [String]
    public let options: [String: String]
    public let flags: Set<String>

    /// `--keys` that are always boolean switches and never take a value.
    /// Keep this in sync with every `args.flag("…")` call site.
    public static let booleanFlags: Set<String> = [
        "json",
        "membership",
        "owned",
        "squash",
        "remove-source-branch",
        "help",
    ]

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
            guard arg.hasPrefix("--") else {
                positionals.append(arg)
                i += 1
                continue
            }

            let body = String(arg.dropFirst(2))

            // --key=value form
            if let eq = body.firstIndex(of: "=") {
                let key = String(body[..<eq])
                let value = String(body[body.index(after: eq)...])
                if booleanFlags.contains(key) {
                    // A boolean switch written as --json=true / --json=false.
                    // Honour truthy values; a falsy value leaves the flag unset.
                    if Self.isTruthy(value) { flags.insert(key) }
                } else {
                    options[key] = value
                }
                i += 1
                continue
            }

            // Known boolean switch: never consumes the next token.
            if booleanFlags.contains(body) {
                flags.insert(body)
                i += 1
                continue
            }

            // Value option: take the next token unless it's another flag or absent.
            if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                options[body] = args[i + 1]
                i += 2
            } else {
                // Dangling --key with no value: record as a flag so it doesn't
                // silently swallow an unrelated token.
                flags.insert(body)
                i += 1
            }
        }

        return ParsedArgs(positionals: positionals, options: options, flags: flags)
    }

    /// Interpret the value of a `--flag=value` boolean switch. An empty value
    /// (bare `--flag=`) counts as true, matching the bare `--flag` form.
    static func isTruthy(_ value: String) -> Bool {
        switch value.lowercased() {
        case "", "true", "1", "yes", "on": return true
        default: return false
        }
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
