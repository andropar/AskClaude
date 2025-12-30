# Shared Task Notes

## Recent Work (2025-12-31)

### Latest Progress - User-Facing Error Handling (NEWEST)
**Added error alerts and banners for user visibility** (AlertManager.swift, ChatSession.swift, ChatView.swift)
1. **Created AlertManager service** (`Services/AlertManager.swift`)
   - Centralized NSAlert dialog management
   - Specific handlers for: CLI not found, auth failures, process crashes
   - Action buttons (e.g., "Download Claude Code", "Open Terminal")

2. **Integrated error banner in ChatView** (ChatView.swift:92-113)
   - Shows dismissible error banner above input bar when session has error
   - Uses existing `ErrorBanner` component (was already defined but unused)
   - Animated transition when errors appear/disappear

3. **Added process crash detection** (ChatSession.swift:106-117, ClaudeProcessManager.swift:22,320-323)
   - New `onProcessCrash` callback in ClaudeProcessManager
   - ChatSession shows alert when Claude exits abnormally (excludes normal exits and SIGINT)
   - Session start errors now show appropriate dialogs

**Result**: Users now see clear error messages for CLI issues, auth problems, and crashes instead of silent failures.

## Earlier Work (2025-12-28)

### Testing Infrastructure Added
**Test files created for ClaudeOutputParser** (AskClaudeTests/ClaudeOutputParserTests.swift)
- Created comprehensive unit test suite with 21 test cases covering:
  - System event parsing
  - Assistant message parsing (text and tool use)
  - User message parsing
  - Result event parsing (success and error cases)
  - Content block events (start, delta, stop)
  - Permission request parsing
  - Edge cases (invalid JSON, unknown types, missing fields)
  - Multiple content types in single message
- Tests ready to be added to Xcode project
- Setup script provided at `AskClaude/setup_tests.sh` with instructions
- **Next step**: Add test target to Xcode project and run tests (see setup_tests.sh)

### Earlier Fix - NotificationCenter Observer Leaks
**Missing observer cleanup** (ChatSession.swift:342-368, AppDelegate.swift:7,28-34,114-120)
1. **SessionManager observer leak** - NotificationCenter observer never removed
   - Added `folderOpenObserver` property to store observer reference
   - Added `deinit` method to properly remove observer on deallocation
   - Prevents potential memory leaks and duplicate notifications

2. **AppDelegate observer leak** - Window notification observer never removed
   - Added `windowBecomeKeyObserver` property to store observer reference
   - Cleanup now happens in `applicationWillTerminate`
   - Follows best practices for NotificationCenter observer management

### Earlier Fix - Streaming Message State Bugs
**Streaming messages not marked complete** (ChatSession.swift:134-150, 261-282)
1. **Bug in `stop()` method** - Streaming messages remained in streaming state when session stopped
   - Fixed: Now marks any streaming message as `isStreaming: false` before clearing state

2. **Bug in `result` event handler** - Missing safety check for streaming messages
   - Fixed: Added safety check to mark streaming message complete before clearing state

### Earlier Fixes - Resource Leaks and File Size Limits
**CSV file size limit missing** (MarkdownContentView.swift:764)
- CSV files were not included in the 10MB size limit check for text files
- Large CSV files (1GB+) could be loaded entirely into memory, causing crashes
- Added "csv" to the list of text file extensions subject to size limits
- Now prevents memory issues when previewing large CSV files

**CFMessagePort resource leak** (IPCClient.swift:7-37)
- Every message from Finder extension created a CFMessagePort but never invalidated it
- Over many invocations, this accumulated system resources (ports, file descriptors)
- Added `defer { CFMessagePortInvalidate(remotePort) }` to ensure cleanup
- Port is now properly released after each message send

### Earlier Fix - Race Condition in Pipe Writes
**Race condition when writing to stdin pipe** (ClaudeProcessManager.swift:161-238)
- Fixed potential crash when session stops during message send
- Problem: Code checked `isRunning` then wrote to pipe in two non-atomic operations
- Race condition: Session could be stopped (closing pipes) between check and write, causing crash
- Solution: Wrapped `FileHandle.write()` calls in try-catch blocks
- Now gracefully handles write failures with error logging instead of crashing
- Affects both `sendMessage()` and `sendPermissionResponse()` methods

### Earlier Fix - Session State Management
**Incomplete state cleanup in ChatSession** (ChatSession.swift:134-158)
1. **Fixed `interrupt()` method** - Now properly cleans up streaming state before adding interrupt message
   - Marks streaming messages as complete before resetting
   - Prevents stale references to `currentStreamingMessageId` and `currentBlockType`
   - Ensures UI consistency when user interrupts Claude

2. **Fixed `stop()` method** - Now resets all session state variables
   - Clears `isProcessing`, `isThinking`, `currentActivity`
   - Resets `pendingPermission`, `currentStreamingMessageId`, `currentBlockType`
   - Prevents stale state when session is stopped and potentially restarted

3. **Fixed force unwrap in AppDelegate** - Changed `statusItem: NSStatusItem!` to optional
   - Eliminates potential crash if `setupMenuBar()` fails
   - Uses safe optional chaining throughout

### Earlier Fix - Memory Safety in ClaudeProcessManager
**Unbounded buffer growth protection** (ClaudeProcessManager.swift:263-286)
- Added 10MB limit on `outputBuffer` to prevent memory exhaustion
- If Claude process sends malformed output without newlines, buffer would grow indefinitely
- Now clears buffer and logs error when limit exceeded
- Also clears buffer on session stop to prevent data leakage between sessions
- Protects against process malfunction or streaming bugs

### Earlier Fixes - Resource Management in MarkdownContentView
1. **Uncancellable network requests in ImageBlockView** (MarkdownContentView.swift:449-553)
   - Network image loading tasks were not stored, so they couldn't be cancelled
   - Added `@State private var imageLoadTask` to store URLSessionDataTask
   - Added `.onDisappear` to cancel task when view disappears
   - Prevents resource waste from image loading continuing after view is dismissed

2. **Missing file size limits in FilePreviewView** (MarkdownContentView.swift:724-764)
   - File previews would attempt to load entire file into memory before truncating
   - Could cause crashes or hangs on very large files (1GB+ text files)
   - Added 10MB limit check for text files before attempting to load
   - Shows user-friendly error message with file size when limit exceeded

### Earlier Fixes - Memory and File Handle Leaks
1. **Timer memory leaks in ChatView.swift** (lines 293-320, 383-430)
   - `BouncingDots` and `ThinkingRow` views were creating timers that never got invalidated
   - Added proper cleanup in `onDisappear` to prevent memory leaks

2. **File handle cleanup in ClaudeProcessManager.swift** (lines 232-254)
   - Added explicit file handle closing before process termination
   - Prevents potential file descriptor leaks during session cleanup

3. **File handle leaks in ClaudeProcessManager.swift** (lines 47-49, 344-346)
   - Fixed leak in `claudePath` property when running `which claude` command
   - Fixed leak in `checkAuthentication()` method when checking stderr output
   - Both methods now properly close file handles after reading data

### Priority Improvements for Next Iteration

1. **Testing Infrastructure** (IN PROGRESS)
   - ✅ ClaudeOutputParser tests created (21 test cases)
   - ⏳ Add test target to Xcode project (manual step required - see setup_tests.sh)
   - 📝 TODO: Add tests for ChatSession message handling
   - 📝 TODO: Add tests for file browser path navigation logic
   - 📝 TODO: Add tests for ClaudeProcessManager

2. **Error Handling** (MOSTLY COMPLETE)
   - ✅ User-facing alert dialogs for auth failures, process crashes
   - ✅ Error banner in ChatView for session errors
   - 📝 TODO: Add retry logic for Claude CLI connection failures

3. **Code Organization**
   - MarkdownContentView.swift: 1,186 lines (extract ImageBlockView, FilePreviewView, etc.)
   - ChatView.swift: 924 lines (extract FileBrowserView, PermissionDialog, etc.)
   - ContentView.swift: 501 lines (consider splitting sidebar)

4. **Session Management**
   - Persist chat history between app launches
   - Add ability to rename sessions
   - Export chat history feature

5. **File Browser Improvements**
   - Add file watching/refresh when files change externally
   - Add context menu for files (copy path, reveal in Finder)
   - Add caching to prevent synchronous reloads on every path change
   - Consider pagination for large file lists

## Build Status
✅ Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O
