# gl Implementation

## Goal

Create a terminal application named `gl` that talks to GitLab through the REST API using environment-based authentication.

The tool should be simple enough to use from a shell, but structured enough to grow into a real operator tool for projects, milestones, issues, notes, and work-item workflows.

## Authentication

The app reads:

- `GITLAB_API_URL`
- `GITLAB_TOKEN`

`GITLAB_API_URL` defines the GitLab host, and `GITLAB_TOKEN` is sent as `PRIVATE-TOKEN` on each request.

## Package structure

The package is a Swift executable package:

- `Package.swift` defines the `gl` executable target.
- `Sources/gl/main.swift` is the entry point.
- `Sources/gl/GitLabAPIClient.swift` owns base URL and auth.
- `Sources/gl/GitLabAPIClient+Commands.swift` holds common GitLab API command helpers.
- `Sources/gl/GLCommand.swift` parses CLI arguments and dispatches behavior.

## Current commands

The first version exposes:

- `gl` - defaults to `whoami`
- `gl whoami`
- `gl project <path>`
- `gl issues <project>`
- `gl milestones <project>`

## Client design

The GitLab client is intentionally lightweight:

- builds request URLs from `GITLAB_API_URL`
- attaches `PRIVATE-TOKEN`
- uses `URLSession`
- prints raw API errors when GitLab returns a non-2xx response

This keeps the implementation easy to debug and easy to extend.

## Extension points

Good next additions:

- create / update / close issues
- add notes to issues
- list and update milestones
- resolve project IDs from `group/project` paths
- support JSON output and human-readable tables
- add a `--project` flag so commands can infer context

## Unknowns to resolve later

- whether the CLI should support GitLab work items beyond issue endpoints
- whether the app should use direct REST calls only or also optional GraphQL
- whether output should be JSON-first or text-first

## Delivery note

This initial scaffold is enough to compile into a terminal tool and provides a clean place to keep expanding the GitLab API surface.
