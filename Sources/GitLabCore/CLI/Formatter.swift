import Foundation

// MARK: - Output formatter

public struct Formatter: Sendable {

    // MARK: Action result

    /// Render the result of a write action that has no response body
    /// (delete / remove). In text mode returns `message`; in JSON mode returns
    /// a machine-readable status object describing what happened.
    public static func actionResult(
        _ message: String,
        json: Bool,
        action: String,
        resource: String,
        id: String
    ) -> String {
        guard json else { return message }
        let payload: [String: String] = [
            "status": "ok",
            "action": action,
            "resource": resource,
            "id": id,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // MARK: Table

    /// Render a simple ASCII table.
    ///
    /// - Parameters:
    ///   - headers: Column header strings.
    ///   - rows: Each element is one row; the number of cells should match `headers.count`.
    public static func table(headers: [String], rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "(none)" }

        var widths = headers.map(\.count)
        for row in rows {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], min(cell.count, 80))
            }
        }

        func pad(_ s: String, to width: Int) -> String {
            let trimmed = s.count > width ? String(s.prefix(width - 1)) + "…" : s
            return trimmed + String(repeating: " ", count: max(0, width - trimmed.count))
        }

        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
        let headerLine = headers.enumerated().map { i, h in pad(h, to: widths[i]) }.joined(separator: "  ")
        let dataLines = rows.map { row -> String in
            row.enumerated().map { i, cell in
                i < widths.count ? pad(cell, to: widths[i]) : cell
            }.joined(separator: "  ")
        }

        return ([headerLine, separator] + dataLines).joined(separator: "\n")
    }

    // MARK: Detail

    /// Render a key-value detail view (used for single-item responses).
    public static func detail(_ fields: [(String, String?)]) -> String {
        let maxKey = fields.compactMap { $0.0.count as Int? }.max() ?? 0
        return fields.compactMap { key, value -> String? in
            guard let v = value, !v.isEmpty else { return nil }
            let padding = String(repeating: " ", count: max(0, maxKey - key.count))
            return "\(key):\(padding)  \(v)"
        }.joined(separator: "\n")
    }

    // MARK: Helpers

    /// Short human-readable date from a full ISO-8601 Date.
    public static func shortDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: d)
    }

    /// Short datetime.
    public static func shortDateTime(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: d)
    }

    /// Truncate a string to a maximum length, appending "…" if needed.
    public static func truncate(_ s: String?, maxLength: Int = 60) -> String {
        guard let s = s, !s.isEmpty else { return "" }
        if s.count <= maxLength { return s }
        return String(s.prefix(maxLength - 1)) + "…"
    }

    // MARK: Named formatters

    public static func formatUser(_ u: GLUser, json: Bool) -> String {
        if json { return u.prettyJSON() }
        return detail([
            ("ID",       "\(u.id)"),
            ("Username", u.username),
            ("Name",     u.name),
            ("Email",    u.email ?? u.publicEmail ?? ""),
            ("State",    u.state),
            ("URL",      u.webUrl),
        ])
    }

    public static func formatProject(_ p: GLProject, json: Bool) -> String {
        if json { return p.prettyJSON() }
        return detail([
            ("ID",           "\(p.id)"),
            ("Name",         p.nameWithNamespace),
            ("Path",         p.pathWithNamespace),
            ("Description",  p.description ?? ""),
            ("Visibility",   p.visibility),
            ("Default branch", p.defaultBranch ?? ""),
            ("Stars",        "\(p.starCount)"),
            ("Forks",        "\(p.forksCount)"),
            ("Open issues",  p.openIssuesCount.map { "\($0)" } ?? ""),
            ("Created",      shortDate(p.createdAt)),
            ("Last activity",shortDate(p.lastActivityAt)),
            ("URL",          p.webUrl),
        ])
    }

    public static func formatProjects(_ list: [GLProject], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Path", "Visibility", "Stars"],
            rows: list.map { p in ["\(p.id)", p.pathWithNamespace, p.visibility, "\(p.starCount)"] }
        )
    }

    public static func formatIssue(_ i: GLIssue, json: Bool) -> String {
        if json { return i.prettyJSON() }
        return detail([
            ("ID",          "#\(i.iid)"),
            ("Title",       i.title),
            ("State",       i.state),
            ("Author",      i.author.username),
            ("Assignees",   i.assignees.map(\.username).joined(separator: ", ")),
            ("Labels",      i.labels.joined(separator: ", ")),
            ("Milestone",   i.milestone?.title ?? ""),
            ("Due date",    i.dueDate ?? ""),
            ("Weight",      i.weight.map { "\($0)" } ?? ""),
            ("Notes",       "\(i.userNotesCount)"),
            ("👍 / 👎",    "\(i.upvotes) / \(i.downvotes)"),
            ("Created",     shortDate(i.createdAt)),
            ("Updated",     shortDate(i.updatedAt)),
            ("Closed",      shortDate(i.closedAt)),
            ("URL",         i.webUrl),
        ])
    }

    public static func formatIssues(_ list: [GLIssue], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["IID", "State", "Title", "Labels", "Assignee", "Milestone"],
            rows: list.map { i in [
                "#\(i.iid)",
                i.state,
                truncate(i.title, maxLength: 50),
                i.labels.joined(separator: ","),
                i.assignees.first?.username ?? "",
                i.milestone?.title ?? "",
            ]}
        )
    }

    public static func formatMilestone(_ m: GLMilestone, json: Bool) -> String {
        if json { return m.prettyJSON() }
        return detail([
            ("ID",          "\(m.id) (iid: \(m.iid))"),
            ("Title",       m.title),
            ("Description", m.description ?? ""),
            ("State",       m.state),
            ("Due date",    m.dueDate ?? ""),
            ("Start date",  m.startDate ?? ""),
            ("Created",     shortDate(m.createdAt)),
            ("Updated",     shortDate(m.updatedAt)),
            ("URL",         m.webUrl),
        ])
    }

    public static func formatMilestones(_ list: [GLMilestone], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "IID", "State", "Title", "Due"],
            rows: list.map { m in ["\(m.id)", "\(m.iid)", m.state, m.title, m.dueDate ?? ""] }
        )
    }

    public static func formatNote(_ n: GLNote, json: Bool) -> String {
        if json { return n.prettyJSON() }
        return detail([
            ("Note ID", "\(n.id)"),
            ("Author",  n.author.username),
            ("System",  n.system ? "yes" : "no"),
            ("Created", shortDate(n.createdAt)),
            ("Body",    n.body),
        ])
    }

    public static func formatNotes(_ list: [GLNote], json: Bool) -> String {
        if json { return list.prettyJSON() }
        let human = list.filter { !$0.system }
        guard !human.isEmpty else { return "(no comments)" }
        return human.map { n in
            "[\(n.id)] \(n.author.username) @ \(shortDate(n.createdAt))\n\(n.body)"
        }.joined(separator: "\n\n---\n\n")
    }

    public static func formatMR(_ m: GLMergeRequest, json: Bool) -> String {
        if json { return m.prettyJSON() }
        return detail([
            ("ID",          "!\(m.iid)"),
            ("Title",       m.title),
            ("State",       m.state),
            ("Source",      m.sourceBranch),
            ("Target",      m.targetBranch),
            ("Author",      m.author.username),
            ("Assignees",   m.assignees.map(\.username).joined(separator: ", ")),
            ("Labels",      m.labels.joined(separator: ", ")),
            ("Milestone",   m.milestone?.title ?? ""),
            ("Draft",       m.draft == true ? "yes" : "no"),
            ("Merge status",m.mergeStatus ?? ""),
            ("Notes",       "\(m.userNotesCount)"),
            ("👍 / 👎",    "\(m.upvotes) / \(m.downvotes)"),
            ("Created",     shortDate(m.createdAt)),
            ("Merged",      shortDate(m.mergedAt)),
            ("URL",         m.webUrl),
        ])
    }

    public static func formatMRs(_ list: [GLMergeRequest], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["IID", "State", "Title", "Source → Target", "Author"],
            rows: list.map { m in [
                "!\(m.iid)",
                m.state,
                truncate(m.title, maxLength: 40),
                "\(m.sourceBranch) → \(m.targetBranch)",
                m.author.username,
            ]}
        )
    }

    public static func formatLabel(_ l: GLLabel, json: Bool) -> String {
        if json { return l.prettyJSON() }
        return detail([
            ("ID",          "\(l.id)"),
            ("Name",        l.name),
            ("Color",       l.color),
            ("Priority",    l.priority.map { "\($0)" } ?? ""),
            ("Description", l.description ?? ""),
        ])
    }

    public static func formatLabels(_ list: [GLLabel], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Name", "Color", "Priority", "Open Issues"],
            rows: list.map { l in ["\(l.id)", l.name, l.color, l.priority.map { "\($0)" } ?? "", l.openIssuesCount.map { "\($0)" } ?? ""] }
        )
    }

    public static func formatGroup(_ g: GLGroup, json: Bool) -> String {
        if json { return g.prettyJSON() }
        return detail([
            ("ID",          "\(g.id)"),
            ("Name",        g.fullName),
            ("Path",        g.fullPath),
            ("Description", g.description ?? ""),
            ("Visibility",  g.visibility),
            ("URL",         g.webUrl),
        ])
    }

    public static func formatGroups(_ list: [GLGroup], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Full Path", "Visibility"],
            rows: list.map { g in ["\(g.id)", g.fullPath, g.visibility] }
        )
    }

    public static func formatMember(_ m: GLMember, json: Bool) -> String {
        if json { return m.prettyJSON() }
        return detail([
            ("ID",           "\(m.id)"),
            ("Username",     m.username),
            ("Name",         m.name),
            ("Access level", GLAccessLevel.name(for: m.accessLevel)),
            ("State",        m.state),
            ("Expires",      m.expiresAt ?? "never"),
        ])
    }

    public static func formatMembers(_ list: [GLMember], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Username", "Name", "Access"],
            rows: list.map { m in ["\(m.id)", m.username, m.name, GLAccessLevel.name(for: m.accessLevel)] }
        )
    }

    public static func formatBranch(_ b: GLBranch, json: Bool) -> String {
        if json { return b.prettyJSON() }
        return detail([
            ("Name",      b.name),
            ("Default",   b.isDefault ? "yes" : "no"),
            ("Protected", b.protected ? "yes" : "no"),
            ("Merged",    b.merged ? "yes" : "no"),
            ("Last commit", b.commit?.shortId ?? ""),
            ("Commit msg",  b.commit?.title ?? ""),
            ("URL",       b.webUrl),
        ])
    }

    public static func formatBranches(_ list: [GLBranch], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["Name", "Default", "Protected", "Merged"],
            rows: list.map { b in [b.name, b.isDefault ? "✓" : "", b.protected ? "✓" : "", b.merged ? "✓" : ""] }
        )
    }

    public static func formatPipeline(_ p: GLPipeline, json: Bool) -> String {
        if json { return p.prettyJSON() }
        return detail([
            ("ID",      "\(p.id)"),
            ("Status",  p.status),
            ("Ref",     p.ref),
            ("SHA",     p.sha),
            ("Source",  p.source ?? ""),
            ("Created", shortDate(p.createdAt)),
            ("Updated", shortDate(p.updatedAt)),
            ("URL",     p.webUrl),
        ])
    }

    public static func formatPipelines(_ list: [GLPipeline], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Status", "Ref", "SHA", "Created"],
            rows: list.map { p in ["\(p.id)", p.status, p.ref, String(p.sha.prefix(8)), shortDate(p.createdAt)] }
        )
    }

    public static func formatJob(_ j: GLJob, json: Bool) -> String {
        if json { return j.prettyJSON() }
        return detail([
            ("ID",        "\(j.id)"),
            ("Name",      j.name),
            ("Stage",     j.stage),
            ("Status",    j.status),
            ("Failure",   j.failureReason ?? ""),
            ("Allow failure", j.allowFailure == true ? "yes" : ""),
            ("Ref",       j.ref ?? ""),
            ("Pipeline",  j.pipeline.map { "\($0.id)" } ?? ""),
            ("Duration",  humanDuration(j.duration)),
            ("Queued",    humanDuration(j.queuedDuration)),
            ("Started",   shortDateTime(j.startedAt)),
            ("Finished",  shortDateTime(j.finishedAt)),
            ("User",      j.user?.username ?? ""),
            ("Artifacts", j.artifactsFile?.filename ?? ""),
            ("URL",       j.webUrl ?? ""),
        ])
    }

    public static func formatJobs(_ list: [GLJob], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Status", "Stage", "Name", "Duration", "Ref"],
            rows: list.map { j in [
                "\(j.id)",
                j.status,
                j.stage,
                truncate(j.name, maxLength: 40),
                humanDuration(j.duration),
                j.ref ?? "",
            ]}
        )
    }

    /// Render a job log. Text mode prints the log as-is (already cleaned and/or
    /// tailed by the caller); JSON mode wraps it so the newlines survive as a
    /// single properly escaped string value.
    public static func formatJobTrace(_ trace: String, jobId: Int, json: Bool) -> String {
        guard json else { return trace }
        let payload: [String: Any] = ["job_id": jobId, "trace": trace]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    /// Report where a job's artifacts archive was written. The zip itself never
    /// goes to stdout — only its path and size.
    public static func formatJobArtifacts(jobId: Int, path: String, byteCount: Int, json: Bool) -> String {
        guard json else {
            return "Artifacts for job \(jobId) written to \(path) (\(byteCount) bytes)."
        }
        let payload: [String: Any] = [
            "status": "ok",
            "action": "downloaded",
            "resource": "job-artifacts",
            "id": "\(jobId)",
            "path": path,
            "bytes": byteCount,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // MARK: Job log cleaning

    /// Make a raw GitLab job log readable.
    ///
    /// Real traces (tens of kilobytes) carry four kinds of noise that hide the
    /// one line you are looking for:
    /// - ANSI escape sequences (colour, `\u{1B}[0K` erase-to-end-of-line)
    /// - `section_start:<ts>:<name>` / `section_end:<ts>:<name>` fold markers,
    ///   emitted as a prefix followed by `\r` and then the human-readable text
    /// - per-line RFC3339 timestamps followed by a four-character stream marker
    ///   (`00O ` stdout, `01E ` stderr, `00O+` a continued line) that GitLab
    ///   16.5+ prefixes to every line
    /// - carriage returns used to redraw progress bars in place
    ///
    /// Lines are collapsed to what a terminal would finally show (the text
    /// after the last `\r`). A line that held nothing but a fold marker is
    /// dropped; every other line survives — including blank ones — so the log
    /// keeps the shape the test runner gave it.
    public static func cleanJobTrace(_ raw: String) -> String {
        var out: [String] = []
        for rawLine in raw.components(separatedBy: "\n") {
            var line = rawLine
            if line.hasSuffix("\r") { line.removeLast() }
            let hadSectionMarker = line.contains("section_start:") || line.contains("section_end:")
            line = stripANSI(line)
            if let last = line.lastIndex(of: "\r") {
                line = String(line[line.index(after: last)...])
            }
            line = stripSectionMarkers(line)
            line = stripLogTimestamp(line)
            if hadSectionMarker, line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    /// Keep only the last `count` lines. Applied *after* cleaning so `--tail n`
    /// means "n lines of readable output", not "n lines of escape codes".
    /// A trailing newline is preserved and does not count as a line.
    public static func tailLines(_ text: String, count: Int) -> String {
        guard count > 0 else { return "" }
        var lines = text.components(separatedBy: "\n")
        var trailingNewline = false
        if lines.last == "" {
            lines.removeLast()
            trailingNewline = true
        }
        guard lines.count > count else { return text }
        let kept = lines.suffix(count).joined(separator: "\n")
        return trailingNewline ? kept + "\n" : kept
    }

    /// Human-readable duration from GitLab's seconds-as-Double.
    public static func humanDuration(_ seconds: Double?) -> String {
        guard let s = seconds, s.isFinite, s >= 0 else { return "" }
        let total = Int(s.rounded())
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes)m \(total % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Remove ANSI/VT100 escape sequences (CSI, OSC and two-character escapes).
    static func stripANSI(_ s: String) -> String {
        guard s.contains("\u{1B}") else { return s }
        var result = ""
        result.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            guard s[i] == "\u{1B}" else {
                result.append(s[i])
                i = s.index(after: i)
                continue
            }
            var j = s.index(after: i)
            guard j < s.endIndex else { break }
            if s[j] == "[" {
                // CSI: ESC [ <params> <final byte in @…~>
                j = s.index(after: j)
                while j < s.endIndex, !("@"..."~").contains(s[j]) { j = s.index(after: j) }
                if j < s.endIndex { j = s.index(after: j) }
            } else if s[j] == "]" {
                // OSC: ESC ] … terminated by BEL or ESC
                j = s.index(after: j)
                while j < s.endIndex, s[j] != "\u{07}", s[j] != "\u{1B}" { j = s.index(after: j) }
                if j < s.endIndex, s[j] == "\u{07}" { j = s.index(after: j) }
            } else {
                j = s.index(after: j)
            }
            i = j
        }
        return result
    }

    /// Drop `section_start:`/`section_end:` fold markers wherever they appear.
    static func stripSectionMarkers(_ s: String) -> String {
        guard s.contains("section_start:") || s.contains("section_end:") else { return s }
        guard let regex = sectionMarkerRegex else { return s }
        let range = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }

    /// Drop a leading RFC3339 timestamp (and GitLab's `00O`-style stream marker).
    static func stripLogTimestamp(_ s: String) -> String {
        guard let regex = logTimestampRegex else { return s }
        let range = NSRange(s.startIndex..., in: s)
        guard let match = regex.firstMatch(in: s, options: [.anchored], range: range),
              let matched = Range(match.range, in: s) else { return s }
        return String(s[matched.upperBound...])
    }

    // Compiled once; `nil` (impossible for these literal patterns) degrades to
    // "leave the line alone" rather than trapping in a CLI.
    // section_start:1709287200:step_script[collapsed=true]
    private static let sectionMarkerRegex = try? NSRegularExpression(
        pattern: "section_(?:start|end):\\d+:[A-Za-z0-9_.\\-]+(?:\\[[^\\]]*\\])?"
    )

    // 2024-03-01T10:00:05.123456Z 00O <line>   — the marker is two hex flag
    // digits, the stream (O = stdout, E = stderr) and a space, or `+` when the
    // line continues the previous one: `… 00O+<line>`.
    private static let logTimestampRegex = try? NSRegularExpression(
        pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:?\\d{2}) (?:[0-9A-Fa-f]{2}[A-Za-z][ +])?"
    )

    public static func formatRelease(_ r: GLRelease, json: Bool) -> String {
        if json { return r.prettyJSON() }
        return detail([
            ("Tag",         r.tagName),
            ("Name",        r.name),
            ("Description", r.description ?? ""),
            ("Author",      r.author?.username ?? ""),
            ("Created",     shortDate(r.createdAt)),
            ("Released",    shortDate(r.releasedAt)),
        ])
    }

    public static func formatReleases(_ list: [GLRelease], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["Tag", "Name", "Released"],
            rows: list.map { r in [r.tagName, r.name, shortDate(r.releasedAt)] }
        )
    }

    public static func formatTag(_ t: GLTag, json: Bool) -> String {
        if json { return t.prettyJSON() }
        return detail([
            ("Name",    t.name),
            ("Target",  t.target),
            ("Message", t.message ?? ""),
            ("Commit",  t.commit?.shortId ?? ""),
        ])
    }

    public static func formatTags(_ list: [GLTag], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["Name", "Target", "Message"],
            rows: list.map { t in [t.name, String(t.target.prefix(10)), t.message ?? ""] }
        )
    }

    public static func formatSnippet(_ s: GLSnippet, json: Bool) -> String {
        if json { return s.prettyJSON() }
        return detail([
            ("ID",          "\(s.id)"),
            ("Title",       s.title),
            ("File",        s.fileName ?? ""),
            ("Visibility",  s.visibility ?? ""),
            ("Description", s.description ?? ""),
            ("Author",      s.author?.username ?? ""),
            ("URL",         s.webUrl ?? ""),
        ])
    }

    public static func formatSnippets(_ list: [GLSnippet], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Title", "File", "Visibility"],
            rows: list.map { s in ["\(s.id)", s.title, s.fileName ?? "", s.visibility ?? ""] }
        )
    }

    public static func formatWorkItem(_ w: GLWorkItem, json: Bool) -> String {
        if json { return w.prettyJSON() }
        return detail([
            ("IID",   "\(w.iid)"),
            ("Title", w.title),
            ("State", w.state ?? ""),
            ("Type",  w.workItemType?.name ?? ""),
            ("Assignees", w.assignees?.map(\.username).joined(separator: ", ") ?? ""),
            ("Milestone", w.milestone?.title ?? ""),
            ("Due date", w.dueDate ?? ""),
            ("Weight", w.weight.map { "\($0)" } ?? ""),
            ("Notes", w.userNotesCount.map { "\($0)" } ?? ""),
            ("URL",   w.webUrl ?? ""),
        ])
    }

    public static func formatWorkItems(_ list: [GLWorkItem], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["IID", "State", "Type", "Title"],
            rows: list.map { w in ["\(w.iid)", w.state ?? "", w.workItemType?.name ?? "", w.title] }
        )
    }

    public static func formatWorkItemTypes(_ list: [GLWorkItemType], json: Bool) -> String {
        if json { return list.prettyJSON() }
        return table(
            headers: ["ID", "Name"],
            rows: list.map { t in [t.id ?? "", t.name] }
        )
    }
}

// prettyJSON() is available on all Encodable arrays via the Encodable extension above.
