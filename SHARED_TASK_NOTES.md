# Shared Task Notes

## Recent Work (2025-12-28)

### Latest Fix - Memory Safety in ClaudeProcessManager
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

1. **Testing Infrastructure** (HIGH PRIORITY)
   - No unit tests currently exist - critical for preventing regressions
   - Add tests for ClaudeOutputParser JSON parsing (handles complex stream-json)
   - Add tests for ChatSession message handling
   - Add tests for file browser path navigation logic

2. **Error Handling**
   - Error messages only logged, not shown to users
   - Add user-facing alert dialogs for errors (auth failures, process crashes)
   - Add retry logic for Claude CLI connection failures

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
