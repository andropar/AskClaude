# Shared Task Notes

## Recent Work (2025-12-30)

### Latest - User-Facing Error Handling (NEWEST)
**Error messages now shown to users** (ChatView.swift, ChatSession.swift)
- Added ErrorBanner display in ChatView when session.error is set
- Enhanced ErrorBanner with user-friendly messages and help text:
  - "Claude CLI not found" shows installation command
  - "Not signed in" shows authentication instructions
  - Process exit errors show retry option
- Added retry button for recoverable errors (not found, launch failures, exit errors)
- Added `retry()` method to ChatSession for restarting after errors
- Added Combine-based error observation to forward processManager errors to session
- Proper cleanup of error observation in `stop()` method

Files changed:
- `ChatView.swift`: Added ErrorBanner usage with retry callback, enhanced ErrorBanner component
- `ChatSession.swift`: Added `retry()` method, `errorObservation` property, `setupErrorHandler()` method

### Testing Infrastructure (IN PROGRESS)
**Test files created for ClaudeOutputParser** (AskClaudeTests/ClaudeOutputParserTests.swift)
- 21 test cases covering system events, messages, content blocks, permissions, edge cases
- Tests ready to be added to Xcode project
- Setup script at `AskClaude/setup_tests.sh`
- **Next step**: Add test target to Xcode project (manual step)

### Earlier Fixes (2025-12-28)
- NotificationCenter observer leak fixes (ChatSession.swift, AppDelegate.swift)
- Streaming message state bugs fixed (stop/result handlers)
- CSV file size limit added (MarkdownContentView.swift)
- CFMessagePort resource leak fixed (IPCClient.swift)
- Race condition in pipe writes fixed (ClaudeProcessManager.swift)
- Session state cleanup improved (interrupt/stop methods)
- Memory safety: 10MB buffer limit (ClaudeProcessManager.swift)
- Image loading cancellation (MarkdownContentView.swift)
- File size limits for previews (MarkdownContentView.swift)
- Timer memory leak fixes (ChatView.swift)
- File handle cleanup (ClaudeProcessManager.swift)

## Priority Improvements for Next Iteration

1. **Testing Infrastructure**
   - Add test target to Xcode project (manual step - see setup_tests.sh)
   - Add tests for ChatSession message handling
   - Add tests for ClaudeProcessManager

2. **Code Organization** (Large Files)
   - MarkdownContentView.swift: 1,186+ lines (extract ImageBlockView, FilePreviewView)
   - ChatView.swift: 980+ lines (extract FileBrowserView, PermissionDialog)
   - ContentView.swift: 501 lines

3. **Session Management**
   - Persist chat history between app launches
   - Add ability to rename sessions
   - Export chat history feature

4. **File Browser Improvements**
   - Add file watching/refresh when files change externally
   - Add context menu for files (copy path, reveal in Finder)
   - Add caching for file list

## Build Status
Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O
