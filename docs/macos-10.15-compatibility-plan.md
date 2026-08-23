# macOS 10.15 Compatibility Plan

## Current Status
- **Branch**: `macos-10.15`
- **System**: Swift 5.3.2 on macOS 10.15 (Catalina)
- **Problem**: Code uses async/await (Swift 5.5+) which doesn't exist in Swift 5.3
- **Package.swift**: Updated for Swift 5.3 and macOS .v10_15 (COMPLETED)

## What Needs to Be Converted

### Files to Modify:
1. **Sources/GitLabCore/API/*.swift** - 18 files with extension methods (~120 functions)
2. **Sources/GitLabCore/GitLabAPIClient.swift** - Core API client (~10 functions)  
3. **Sources/GitLabCore/CLI/GLCommand.swift** - Command router
4. **Tests/GitLabCoreTests/*.swift** - Test files (~15+ files)

### Conversion Pattern Required:
```swift
// Before (Swift 5.5+)
func foo() async throws -> T {
    return try await bar()
}

// After (Swift 5.3 compatible)  
func foo(completion: @escaping (Result<T, Error>) -> Void) {
    bar { result in
        completion(result)
    }
}
```

### Additional Changes:
- Remove `@Sendable` annotations (Swift 5.5+ feature)
- Remove `nonisolated(unsafe)` (Swift 6.0 feature)

## Implementation Steps

### Phase 1: Core API Client - IN PROGRESS
- [ ] Convert GitLabAPIClient.swift async request methods to completion handlers
- Status: Script partially working but has bugs with multi-line signatures

### Phase 2: API Extensions  
- [ ] Convert all Sources/GitLabCore/API/*.swift files
- Status: Partial conversion attempted, needs debugging

### Phase 3: CLI Layer
- [ ] Update GLCommand.swift for completion handler style
- Status: Not yet started

### Phase 4: Tests
- [ ] Update test files to use new API
- Status: Not yet started

## Progress Log

### 2024-08-23
- Created macos-10.15 branch
- Updated Package.swift for Swift 5.3 and macOS .v10_15
- Attempted automated conversion scripts but they have bugs:
  - Multi-line function signatures not handled correctly
  - Parameter parsing has issues with nested parentheses
  - Duplicate function signatures generated

### Remaining Work:
Need to carefully rewrite each async function signature and body manually, or fix the conversion script to handle:
1. Multi-line function declarations (params span multiple lines)
2. Nested parentheses in type signatures  
3. Proper parameter extraction between `(` and `)`
4. Return type extraction after `->`
5. Correct closing brace matching
