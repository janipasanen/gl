# Contributing to gl

Thank you for your interest in contributing to `gl`! This document provides guidelines for contributing to this project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment.

## License

By contributing to this project, you agree that your contributions will be licensed under the [GNU General Public License v3](LICENCE.md).

## How to Contribute

### Reporting Bugs

- Search the [issue tracker](https://gitlab.com/janipasanen/gl/-/issues) to see if the bug has already been reported.
- If not, create a new issue. Provide a clear description, steps to reproduce, and your environment details (macOS version, Swift version).

### Suggesting Enhancements

- Open an issue with a clear title and description of the proposed enhancement.
- Explain the use case and why this would be a valuable addition to `gl`.

### Pull Requests (Merge Requests)

We use the standard fork-and-pull model:

1. **Fork** the repository on GitLab.
2. **Clone** your fork locally.
3. **Create a branch** for your changes: `git checkout -b feature/your-feature-name`.
4. **Implement** your changes. Ensure you follow the existing code style.
5. **Write tests** for your changes. We aim for high test coverage of the API surface and CLI logic.
6. **Run tests** to ensure everything is working correctly: `swift test`.
7. **Commit** your changes with a descriptive message.
8. **Push** your branch to your fork.
9. **Open a Merge Request** against the `main` branch of the original repository.

## Development Workflow

### Requirements

- macOS 14+
- Swift 6.0+

### Building

```bash
swift build
```

### Testing

All logic in `GitLabCore` should be covered by unit tests. We use `MockURLProtocol` to mock GitLab API responses.

```bash
swift test
```

### Project Structure

- `Sources/gl/`: CLI entry point and command routing.
- `Sources/GitLabCore/`: Core logic, API client, and models.
- `Tests/GitLabCoreTests/`: Unit tests and fixtures.

## Code Style

- Use standard Swift naming conventions (PascalCase for types, camelCase for variables/functions).
- Keep functions small and focused.
- Ensure `Codable` models match the GitLab API v4 documentation exactly.
- Avoid external dependencies unless absolutely necessary. `gl` aims to be a lightweight tool using Apple's standard libraries where possible.

Thank you for helping make `gl` better!
