# gl Implementation

## Goal

`gl` is a terminal application that talks to GitLab through the REST API v4 using
environment-based authentication. It is simple to use from a shell but structured
to act as a real operator tool for projects, issues, merge requests, milestones,
notes, pipelines, branches, releases, tags, members, and work items.

## Authentication

The app reads these environment variables:

- `GITLAB_API_URL` — the GitLab base URL. Both `https://gitlab.com` and
  `https://gitlab.com/api/v4` are accepted (a trailing `/api/v4` and trailing
  slashes are normalised away). The URL must have an `http`/`https` scheme and a
  host, or construction fails with `Invalid GitLab API URL`.
- `GITLAB_TOKEN` — a personal access token with the `api` scope, sent as the
  `PRIVATE-TOKEN` header on every request.
- `GITLAB_TOKEN_COMMAND` — optional. When `GITLAB_TOKEN` is unset, this command is
  run via `/bin/sh -c` and its trimmed stdout is used as the token, so the secret
  need never live in an env var or plaintext file (e.g. a macOS Keychain lookup).
  An explicit `GITLAB_TOKEN` takes precedence; a non-zero exit or empty output errors.

## Package structure

Swift executable package (`swift-tools-version: 6.0`, macOS 14+):

- `Package.swift` — defines the `gl` executable and the `GitLabCore` library.
- `Sources/gl/main.swift` — entry point: reads env, parses args, runs the command.
- `Sources/GitLabCore/GitLabAPIClient.swift` — base URL, auth, request/encode/decode
  helpers. Builds request URLs with `URLComponents.percentEncodedPath` so the
  `%2F`-encoded `namespace/project` paths are not double-encoded.
- `Sources/GitLabCore/Models.swift` — all `Codable` models and parameter structs.
- `Sources/GitLabCore/API/*.swift` — one file per resource (Issues, MergeRequests,
  Milestones, Labels, Groups, Members, Branches, Pipelines, Releases, Tags,
  WorkItems, …), each an extension on `GitLabAPIClient`.
- `Sources/GitLabCore/CLI/ArgumentParser.swift` — `ParsedArgs` (positionals,
  options, flags).
- `Sources/GitLabCore/CLI/Formatter.swift` — table / detail / JSON output.
- `Sources/GitLabCore/CLI/GLCommand.swift` — command routing and dispatch, plus the
  `gl help` text.

## Argument parsing

`ParsedArgs.parse` classifies each token:

- **Positional** — anything not starting with `--`.
- **Option** — `--key value` or `--key=value`.
- **Flag** — a boolean switch listed in `ParsedArgs.booleanFlags`
  (`json`, `membership`, `owned`, `squash`, `remove-source-branch`, `help`).

Boolean flags are recognised **by name**, not by guessing from the next token, so
`--json` (and the other switches) can appear anywhere on the line without
swallowing the following positional. When adding a new boolean flag, add it to
`booleanFlags` so it is not parsed as a value option.

## Output

Every command takes a global `--json` flag. In text mode commands print tables or
detail blocks; in JSON mode they print pretty-printed JSON. Read and
create/update/close/reopen commands emit the affected object; delete/remove
commands emit a status object (`{"status":"ok","action":"deleted",…}`).

## GraphQL

`GitLabAPIClient.graphQL(query:variablesJSON:)` POSTs to `<base>/api/graphql` (note:
`/api/graphql`, **not** `/api/v4`), authenticating with `Authorization: Bearer`
(plus `PRIVATE-TOKEN` for compatibility). It returns the pretty-printed `data`
object and throws `ClientError.graphQLError` when the response carries top-level
`errors`. The `gl graphql` command (alias `gql`) exposes this for raw
queries/mutations sourced from `--query`, `--file`, a positional argument, or stdin,
with optional `--variables` (a JSON object). This is the path for APIs not exposed
over REST — e.g. work items on gitlab.com, whose REST endpoints return 404 there.

## Testing

`swift test` runs the suite under `Tests/GitLabCoreTests/`, which uses a
`MockURLProtocol` URL-session double to assert on request URLs, bodies, query
items, decoding, argument parsing, command routing, and formatting.
