# gl — GitLab CLI

`gl` is a Swift command-line tool for GitLab. It covers the full REST API v4 surface for the resources that matter most in day-to-day project work: projects, issues, milestones, merge requests, labels, groups, members, branches, pipelines, releases, tags, work items, and snippets.

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14+ |
| Swift | 6.0+ (bundled with Xcode 16+) |

---

## Build

```bash
# Debug build
swift build

# Release build (install to /usr/local/bin)
swift build -c release
cp .build/release/gl /usr/local/bin/gl
```

---

## Run tests

```bash
swift test
```

---

## Environment variables

| Variable | Description |
|---|---|
| `GITLAB_API_URL` | Base URL of your GitLab instance, e.g. `https://gitlab.com` |
| `GITLAB_TOKEN` | Personal access token with `api` scope |
| `GITLAB_TOKEN_COMMAND` | Optional. A command whose stdout is used as the token when `GITLAB_TOKEN` is unset — keeps the token out of env vars and plaintext files |

### Where to find your credentials

**`GITLAB_API_URL`**
- For GitLab.com use `https://gitlab.com`
- For self-managed instances use the root URL, e.g. `https://gitlab.mycompany.com`
- The `/api/v4` suffix is optional — both `https://gitlab.com` and `https://gitlab.com/api/v4` work. The URL must include an `http://` or `https://` scheme and a host, otherwise `gl` exits with `Invalid GitLab API URL`.

**`GITLAB_TOKEN`**
1. Sign in to GitLab
2. Go to **User Settings → Access Tokens** (or `/-/user_settings/personal_access_tokens`)
3. Create a token with the **`api`** scope
4. Copy the token value — it is shown only once

Set the variables in your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export GITLAB_API_URL=https://gitlab.com
export GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
```

#### Keeping the token out of env vars and files

Putting the token in `GITLAB_TOKEN` means it lives in your shell environment and (usually) in a plaintext profile — both readable by anything running as you, including AI agents that dump `env` or read `~/.zshrc`. Instead, set **`GITLAB_TOKEN_COMMAND`**: when `GITLAB_TOKEN` is unset, `gl` runs this command (via `/bin/sh -c`) and uses its trimmed stdout as the token. The token never sits in an env var or a file.

macOS Keychain example — store once, then reference it:

```bash
security add-generic-password -a "$USER" -s gitlab-gl-token -w   # prompts for the token
export GITLAB_TOKEN_COMMAND='security find-generic-password -a "$USER" -s gitlab-gl-token -w'
```

Works with any secret source (`pass`, 1Password CLI, Vault, etc.). If `GITLAB_TOKEN` is also set, it takes precedence. A non-zero exit or empty output is reported as an error.

---

## Usage

```
gl [--json] <resource> <subcommand> [args] [options]
```

Pass `--json` anywhere — before the resource, between subcommand and arguments, or at the end — to get raw pretty-printed JSON instead of formatted tables. All three forms are equivalent:

```bash
gl --json issues get mygroup/proj 45
gl issues --json get mygroup/proj 45
gl issues get mygroup/proj 45 --json
```

Delete/remove actions return a JSON status object in `--json` mode (e.g. `{"action":"deleted","id":"45","resource":"issue","status":"ok"}`) and a plain confirmation line otherwise. Options may also be written as `--key=value`.

---

### whoami

```bash
gl
gl whoami
```

---

### Projects

```bash
gl project <path>                    # Get a project by path or ID
gl projects list                     # List accessible projects
gl projects list --membership        # Only projects you're a member of
gl projects list --owned             # Only projects you own
gl projects list --search gitlab     # Search projects
gl projects get <path>
gl projects search <query>
```

---

### Issues

```bash
gl issues list <project>
gl issues list <project> --state opened   # 'open' is accepted as an alias
gl issues list <project> --state closed
gl issues list <project> --labels "bug,high"
gl issues list <project> --milestone "v1.0"
gl issues list <project> --assignee jdoe
gl issues list <project> --assignee-id 2
gl issues list <project> --search "crash"
gl issues list <project> --page 2 --per-page 50

gl issues get    <project> <iid>
gl issues create <project> --title "Fix login bug"
gl issues create <project> --title "…" --description "…" --labels "bug" --milestone-id 10 --due-date 2024-12-31 --weight 3 --assignee jdoe
gl issues update <project> <iid> --title "New title"
gl issues update <project> <iid> --add-labels "regression" --remove-labels "high"
gl issues close  <project> <iid>
gl issues reopen <project> <iid>
gl issues delete <project> <iid>
gl issues move   <project> <iid> --to-project-id <target-id>
gl issues subscribe   <project> <iid>
gl issues unsubscribe <project> <iid>
gl issues time-estimate <project> <iid> --duration 3h30m
gl issues time-spent    <project> <iid> --duration 1h
```

#### Issue notes (comments)

```bash
gl issues notes list   <project> <iid>
gl issues notes get    <project> <iid> <note-id>
gl issues notes create <project> <iid> --body "Looks good"
gl issues notes update <project> <iid> <note-id> --body "Updated comment"
gl issues notes delete <project> <iid> <note-id>
```

---

### Milestones

```bash
gl milestones list   <project>
gl milestones list   <project> --state active
gl milestones list   <project> --state closed
gl milestones list   <project> --search "v1"
gl milestones get    <project> <id>
gl milestones create <project> --title "v2.0" --due-date 2024-06-30 --start-date 2024-03-01
gl milestones update <project> <id> --title "v2.0 GA" --state-event close
gl milestones delete <project> <id>
gl milestones issues         <project> <id>
gl milestones merge-requests <project> <id>
```

---

### Merge Requests

```bash
gl mr list   <project>
gl mr list   <project> --state opened
gl mr list   <project> --state merged
gl mr list   <project> --source-branch feature/x
gl mr list   <project> --target-branch main
gl mr get    <project> <iid>
gl mr create <project> --source feature/x --target main --title "Add feature X"
gl mr create <project> --source feature/x --target main --title "…" --description "…" --labels "feature" --milestone-id 5
gl mr update <project> <iid> --title "New title"
gl mr update <project> <iid> --state-event close
gl mr merge  <project> <iid>
gl mr merge  <project> <iid> --squash --remove-source-branch
gl mr close  <project> <iid>
gl mr reopen <project> <iid>
gl mr approve   <project> <iid>
gl mr unapprove <project> <iid>
```

#### MR notes (comments)

```bash
gl mr notes list   <project> <iid>
gl mr notes create <project> <iid> --body "LGTM"
gl mr notes update <project> <iid> <note-id> --body "Updated"
gl mr notes delete <project> <iid> <note-id>
```

---

### Labels

```bash
gl labels list   <project>
gl labels get    <project> <id>
gl labels create <project> --name "bug" --color "#d9534f" --priority 2
gl labels create <project> --name "feature" --color "#5cb85c" --description "New feature"
gl labels update <project> <id> --name "defect" --color "#f00" --priority 3
gl labels delete <project> <id>
```

---

### Groups

```bash
gl groups list
gl groups list --owned
gl groups list --search acme
gl groups get      <id-or-path>
gl groups projects <id-or-path>
gl groups subgroups <id-or-path>
gl groups members   <id-or-path>

# Group milestones
gl groups milestones list   <group>
gl groups milestones get    <group> <id>
gl groups milestones create <group> --title "Q2" --due-date 2024-06-30
gl groups milestones update <group> <id> --state-event close
gl groups milestones delete <group> <id>
```

---

### Members

```bash
gl members list   <project>
gl members list   <project> --search alice
gl members add    <project> --user <user-id> --access-level 30
gl members remove <project> --user <user-id>
```

**Access levels:** `0` No access · `5` Minimal · `10` Guest · `20` Reporter · `30` Developer · `40` Maintainer · `50` Owner

---

### Branches

```bash
gl branches list   <project>
gl branches list   <project> --search feature
gl branches get    <project> <branch>
gl branches create <project> --name feature/x --ref main
gl branches delete <project> <branch>
```

---

### Pipelines

```bash
gl pipelines list   <project>
gl pipelines list   <project> --ref main
gl pipelines list   <project> --status running
gl pipelines list   <project> --status failed
gl pipelines get    <project> <id>
gl pipelines cancel <project> <id>
gl pipelines retry  <project> <id>
gl pipelines delete <project> <id>
```

---

### Releases

```bash
gl releases list   <project>
gl releases get    <project> <tag>
gl releases create <project> --tag v1.0.0 --name "Version 1.0" --description "Changelog…"
gl releases create <project> --tag v1.0.0 --name "Version 1.0" --ref main
gl releases delete <project> <tag>
```

---

### Work Items

Work items use GitLab's **GraphQL** API (the REST `/work_items` endpoints return 404 on gitlab.com), so these commands work on gitlab.com as well as self-managed instances.

```bash
gl workitems list   <project>                 # newest first
gl workitems list   <project> --state opened --first 50
gl workitems get    <project> <iid>
gl workitems types  <project>                 # list type IDs (needed for create)
gl workitems create <project> --title "My task" --type Task
gl workitems create <project> --title "My task" --type-id gid://gitlab/WorkItems::Type/1 --description "…"
gl workitems create <project> --title "Task" --type Task \
  --assignee jdoe --labels "bug,backend" --milestone-id 12 --weight 3 \
  --start-date 2026-06-01 --due-date 2026-06-30
gl workitems update <project> <iid> --title "New title" --description "…" \
  --assignee jdoe --labels "regression" --remove-labels "backend" --weight 5
gl workitems close  <project> <iid>
gl workitems reopen <project> <iid>
gl workitems delete <project> <iid>
```

- `--type <name>` (e.g. `Task`, `Issue`, `Incident`) is resolved to its global ID via `workitems types`; `--type-id <gid>` passes one explicitly.
- Update/close/reopen/delete address the item by `iid`; the global ID required by the GraphQL mutations is resolved automatically.
- **Widget fields** map to GraphQL widgets, with names/IDs resolved for you: `--assignee <user>` / `--assignee-ids <id1,id2>` (assignees), `--labels` (and `--remove-labels` on update), `--milestone-id`, `--weight`, `--start-date`, `--due-date`. A widget the work item *type* doesn't support (e.g. `--weight` without a premium tier) comes back as a GraphQL error.

---

### Tags

```bash
gl tags list   <project>
gl tags list   <project> --search v1
gl tags get    <project> <tag>
gl tags create <project> --name v1.0.0 --ref main --message "Release 1.0.0"
gl tags delete <project> <tag>
```

---

### Snippets

```bash
gl snippets list   <project>
gl snippets get    <project> <id>

# Create from literal content…
gl snippets create <project> --title "Helper" --file-name helper.sh --content "echo hi"
# …or from a local file (file name is derived from the path if --file-name is omitted)
gl snippets create <project> --title "Helper" --file helper.sh --visibility internal

# Edit / change an existing snippet
gl snippets update <project> <id> --title "Renamed"
gl snippets update <project> <id> --file helper.sh
gl snippets update <project> <id> --visibility public

gl snippets delete <project> <id>
```

**Visibility:** `private` (default) · `internal` · `public`

---

### GraphQL

`gl graphql` (alias `gql`) runs a raw query or mutation against GitLab's GraphQL endpoint (`/api/graphql`) and prints the `data` object as JSON. Use it for parts of the API that aren't exposed over REST — most notably **work items on gitlab.com**, where the REST `/projects/:id/work_items` endpoints return 404.

```bash
# query from a flag, a file, a positional argument, or stdin
gl graphql --query '{ currentUser { name username } }'
gl graphql --file query.graphql --variables '{"fullPath":"mygroup/myproject"}'
gl graphql '{ currentUser { name } }'
echo '{ currentUser { name } }' | gl graphql
```

Work-items examples (GraphQL-only on gitlab.com):

```bash
# List work items
gl graphql --query '
  query($p: ID!) {
    project(fullPath: $p) {
      workItems(first: 20, sort: CREATED_DESC) {
        nodes { id iid title state workItemType { name } webUrl }
        pageInfo { hasNextPage endCursor }
      }
    }
  }' --variables '{"p":"mygroup/myproject"}'

# Get one work item by iid
gl graphql --query '{ project(fullPath:"mygroup/myproject") { workItems(iid:"45") { nodes { id iid title state } } } }'

# Find the work-item type IDs you can create
gl graphql --query '{ project(fullPath:"mygroup/myproject") { workItemTypes { nodes { id name } } } }'

# Create a work item
gl graphql --query '
  mutation($input: WorkItemCreateInput!) {
    workItemCreate(input: $input) { workItem { id iid title } errors }
  }' --variables '{"input":{"namespacePath":"mygroup/myproject","title":"New task","workItemTypeId":"gid://gitlab/WorkItems::Type/1"}}'

# Close a work item (note: mutations take the global id, gid://gitlab/WorkItem/<id>)
gl graphql --query '
  mutation($input: WorkItemUpdateInput!) {
    workItemUpdate(input: $input) { workItem { id state } errors }
  }' --variables '{"input":{"id":"gid://gitlab/WorkItem/12345","stateEvent":"CLOSE"}}'
```

Authentication uses the same `GITLAB_TOKEN` / `GITLAB_TOKEN_COMMAND` as the rest of the tool (sent as `Authorization: Bearer`). GraphQL request errors are surfaced as `GraphQL error: …`.

---

## Project layout

```
Sources/
  gl/
    main.swift                  — CLI entry point
  GitLabCore/
    GitLabAPIClient.swift       — Base client, auth, request helpers
    Models.swift                — All Codable models and param structs
    API/
      Users.swift
      Projects.swift
      Issues.swift
      IssueNotes.swift
      Milestones.swift
      GroupMilestones.swift
      MergeRequests.swift
      MRNotes.swift
      Labels.swift
      Groups.swift
      Members.swift
      Branches.swift
      Pipelines.swift
      Releases.swift
      Tags.swift
      WorkItems.swift
      Snippets.swift
    CLI/
      ArgumentParser.swift      — ParsedArgs (positionals + options + flags)
      Formatter.swift           — Table and detail formatters
      GLCommand.swift           — Command routing and dispatch
Tests/
  GitLabCoreTests/
    MockURLProtocol.swift       — URLProtocol test double
    Fixtures.swift              — JSON fixture strings
    APIClientTests.swift
    ArgumentParserTests.swift
    FormatterTests.swift
    GLCommandTests.swift
    UserAPITests.swift
    ProjectAPITests.swift
    IssueAPITests.swift
    MilestoneAPITests.swift
    MRAPITests.swift
    LabelAPITests.swift
    GroupAPITests.swift
    BranchAPITests.swift
    PipelineAPITests.swift
    ReleaseAPITests.swift
    WorkItemAPITests.swift
    SnippetAPITests.swift
```

---

## Examples

```bash
# Set up credentials
export GITLAB_API_URL=https://gitlab.com
export GITLAB_TOKEN=glpat-xxxx

# Who am I?
gl whoami

# List open issues in my project (JSON)
gl issues list mygroup/myproject --state opened --json

# Create a bug issue
gl issues create mygroup/myproject \
  --title "Login fails on mobile" \
  --labels "bug,mobile" \
  --milestone-id 12 \
  --weight 3

# Comment on an issue
gl issues notes create mygroup/myproject 42 --body "Reproduced on iOS 17"

# Open a merge request and merge it
gl mr create mygroup/myproject \
  --source fix/login-mobile \
  --target main \
  --title "Fix mobile login"
gl mr merge mygroup/myproject 7 --squash --remove-source-branch

# See recent pipelines
gl pipelines list mygroup/myproject --ref main

# Create a release
gl releases create mygroup/myproject \
  --tag v2.1.0 \
  --name "Version 2.1.0" \
  --description "Bug fixes and performance improvements"
```
