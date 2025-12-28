# AskClaude Tests

This directory contains unit tests for the AskClaude application.

## Current Test Coverage

### ClaudeOutputParserTests.swift (21 tests)

Comprehensive tests for the `ClaudeOutputParser` enum that parses Claude CLI stream-json output.

**Test Categories:**
- **System Events**: Session startup, model info, tools available
- **Assistant Messages**: Text responses, tool use detection
- **User Messages**: User input echo parsing
- **Result Events**: Success and error cases, cost/duration tracking
- **Content Blocks**: Start/delta/stop events for text, thinking, and tool use
- **Permission Requests**: Bash commands, file operations
- **Edge Cases**: Invalid JSON, empty strings, unknown types, missing fields

## Adding the Test Target

If the test target hasn't been added to Xcode yet, follow these steps:

1. Open `AskClaude.xcodeproj` in Xcode
2. Go to **File > New > Target...**
3. Select **Unit Testing Bundle** under macOS
4. Click **Next**
5. Product Name: `AskClaudeTests`
6. Click **Finish**
7. When prompted, click **Activate** to activate the scheme
8. Delete the auto-generated test file
9. Right-click on the **AskClaudeTests** group in the project navigator
10. Select **Add Files to "AskClaude"...**
11. Navigate to and select the `AskClaudeTests` folder
12. Ensure **Add to targets: AskClaudeTests** is checked
13. Click **Add**

Alternatively, run `./setup_tests.sh` from the AskClaude directory for detailed instructions.

## Running Tests

### In Xcode
- Press **Cmd+U** to run all tests
- Click the diamond next to individual test methods to run specific tests
- View results in the Test Navigator (Cmd+6)

### Command Line
```bash
xcodebuild test -scheme AskClaude -destination 'platform=macOS'
```

## Test Coverage Goals

✅ **ClaudeOutputParser** - Fully tested (21 tests)
📝 **ChatSession** - TODO: Message handling, state management, permission flow
📝 **ClaudeProcessManager** - TODO: Process lifecycle, I/O handling, error cases
📝 **SessionManager** - TODO: Session creation, switching, cleanup

## Writing New Tests

When adding new test files:

1. Create test file in this directory: `AskClaudeTests/YourComponentTests.swift`
2. Import XCTest and the app module:
   ```swift
   import XCTest
   @testable import AskClaude
   ```
3. Create test class inheriting from `XCTestCase`
4. Add test methods prefixed with `test`
5. Add the file to the test target in Xcode

## Best Practices

- **Test naming**: Use descriptive names like `testParseSystemEvent()` or `testHandleInvalidJSON()`
- **Arrange-Act-Assert**: Structure tests clearly with setup, execution, and verification
- **Edge cases**: Always test boundary conditions, invalid input, and error states
- **Isolation**: Each test should be independent and not rely on other tests
- **Fast tests**: Keep tests quick; mock expensive operations
- **Clear assertions**: Use specific XCTest assertions with helpful failure messages

## CI/CD Integration

To integrate with CI/CD pipelines:

```bash
# Run tests and generate output
xcodebuild test -scheme AskClaude -destination 'platform=macOS' \
  -resultBundlePath ./TestResults.xcresult

# Check exit code for pass/fail
if [ $? -eq 0 ]; then
  echo "✅ All tests passed"
else
  echo "❌ Tests failed"
  exit 1
fi
```
