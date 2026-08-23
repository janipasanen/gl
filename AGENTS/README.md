# Agent Instructions for macOS 10.15 Compatibility

## When asked to adapt this code for macOS 10.15:

### Step 1: Create the Branch
```bash
git checkout -b macos-10.15
```

### Step 2: Update Package.swift
Change from:
```swift
// swift-tools-version: 6.0
platforms: [.macOS(.v14)],
.targets: [.executableTarget(...)]
```
To:
```swift
// swift-tools-version:5.3  
platforms: [.macOS(.v10_15)],
.targets: [.target(...)]  // executableTarget requires Swift 5.4+
```

### Step 3: Reference the Plan
See `docs/macos-10.15-compatibility-plan.md` for the full conversion plan and progress tracking.

### Step 4: Progress Tracking
Update `docs/macos-10.15-compatibility-plan.md` with your progress as you work through each phase.

## Key Constraints:
- **Swift 5.3** (system compiler) doesn't support `async throws`, `try await`, or `@Sendable`
- **Must use completion handlers**: `(Result<T, Error>) -> Void`
- All async functions need to be converted to completion handler style

## Quick Reference
- **Project Root**: `/Users/jani/Documents/Developer/JMPasanenIT/AI/gl`
- **Branch**: `macos-10.15`  
- **Swift Version**: 5.3.2 (Apple Swift version 5.3.2)
- **macOS Version**: 10.15 (Catalina)

## Files to Convert

### Priority 1: Core Dependencies
1. Sources/GitLabCore/GitLabAPIClient.swift
2. Sources/GitLabCore/CLI/GLCommand.swift

### Priority 2: API Extensions (~18 files)
All Files in Sources/GitLabCore/API/

### Priority 3: Tests (~15+ files)
All Files in Tests/GitLabCoreTests/

## Important Notes:
- Multi-line function signatures (params spanning multiple lines) are particularly challenging
- The async keyword in Swift 5.3 doesn't exist - code simply cannot parse with `async throws`
- Complete rewrite of ~100+ function signatures required
- See docs/macos-10.15-compatibility-plan.md for detailed progress tracking
