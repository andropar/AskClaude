# Shared Task Notes

## Recent Work (2025-12-31)

### Latest Progress - User-Facing Error Handling Added
**Errors now displayed to users with retry option**

Previously, errors were only logged to console. Now users see errors in the UI with ability to retry.

1. **ErrorBanner in ChatView** (ChatView.swift:35-49)
   - Displays session errors at top of chat area
   - Uses existing but unused `ErrorBanner` component
   - Includes dismiss (X) button to clear error
   - Added retry button for recoverable errors

2. **ErrorBanner enhanced** (ChatView.swift:547-601)
   - Added optional `onRetry` callback
   - Shows "Retry" button when callback provided
   - Increased line limit from 1 to 2 for longer messages

3. **Session retry functionality** (ChatSession.swift:105-109)
   - Added `retry()` method to ChatSession
   - Clears error and restarts session

4. **Process termination errors propagated** (ClaudeProcessManager.swift:22, 320-324; ChatSession.swift:88-95)
   - Added `onError` callback to ClaudeProcessManager
   - Fires when Claude process exits with non-zero code
   - ChatSession hooks into this to show errors in UI
   - Clears processing/thinking state on error

## Earlier Work (2025-12-28)

### Testing Infrastructure Added
**Test files created for ClaudeOutputParser** (AskClaudeTests/ClaudeOutputParserTests.swift)
- 21 test cases covering parsing, edge cases, error handling
- Tests ready to be added to Xcode project
- Setup script at `AskClaude/setup_tests.sh`
- **Next step**: Add test target to Xcode project and run tests

### Bug Fixes Applied
- NotificationCenter observer leaks in SessionManager and AppDelegate
- Streaming message state not clearing on session stop
- CSV file size limit missing in file preview
- CFMessagePort resource leak in Finder extension
- Race condition in stdin pipe writes
- Session state management cleanup
- Unbounded buffer growth protection (10MB limit)
- Network request cancellation in ImageBlockView
- Timer memory leaks in animated views
- File handle leaks in ClaudeProcessManager

### Priority Improvements for Next Iteration

1. **Testing Infrastructure** (IN PROGRESS)
   - ClaudeOutputParser tests created (21 test cases)
   - Add test target to Xcode project (manual step - see setup_tests.sh)
   - TODO: Add tests for ChatSession, ClaudeProcessManager, file browser

2. **Code Organization**
   - MarkdownContentView.swift: 1,186 lines (extract views)
   - ChatView.swift: ~950 lines (extract FileBrowserView, PermissionDialog)
   - ContentView.swift: 501 lines (consider splitting sidebar)

3. **Session Management**
   - Persist chat history between app launches
   - Add ability to rename sessions
   - Export chat history feature

4. **File Browser Improvements**
   - Add file watching/refresh when files change externally
   - Add context menu for files (copy path, reveal in Finder)
   - Add caching to prevent synchronous reloads
   - Consider pagination for large file lists

## Build Status
Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O
