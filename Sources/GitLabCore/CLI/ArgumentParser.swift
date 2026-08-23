import Foundation

public struct ParsedArgs {
    let positional: [String]
    let options: [String: String]

    public static func parse(_ arguments: [String]) -> ParsedArgs {
        var positional: [String] = []
        var options: [String: String] = [:]
        var skipNext = false

        for (i, arg) in arguments.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }

            if arg.hasPrefix("--") && arg.count > 2 {
                // Long option like --option=value or --option value
                if let equalsIndex = arg.firstIndex(of: "=") {
                    let key = String(arg[arg.index(after: arg.startIndex)...equalsIndex])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "="))
                    options[key] = String(arg[arg.index(equalsIndex, offsetBy: 1)...])
                } else if i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-") {
                    let key = String(arg[arg.index(after: arg.startIndex)..<arg.endIndex])
                    options[key] = arguments[i + 1]
                    skipNext = true
                } else {
                    options[String(arg[arg.index(after: arg.startIndex)...])] = "true"
                }
            } else if arg.hasPrefix("-") && arg.count > 1 && !arg.hasPrefix("--") {
                // Short option like -o value or -ovalue
                if i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-") {
                    let key = String(arg[arg.index(after: arg.startIndex)..<arg.endIndex])
                    options[key] = arguments[i + 1]
                    skipNext = true
                } else {
                    let key = String(arg[arg.index(after: arg.startIndex)...])
                    options[key] = "true"
                }
            } else if !arg.hasPrefix("-") {
                positional.append(arg)
            }
        }

        return ParsedArgs(positional: positional, options: options)
    }

    public func positional(_ index: Int) -> String? {
        guard index < positional.count else { return nil }
        return positional[index]
    }

    public func option(_ key: String) -> String? {
        return options[key] ?? options["\(key)s"] // plural variations
    }

    public func flag(_ key: String) -> Bool {
        return options[key] == "true" || options[key] == ""
    }
}
