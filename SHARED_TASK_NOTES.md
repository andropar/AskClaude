# Shared Task Notes

## Recent Work (2025-12-28)

### Latest Fixes - Resource Management in MarkdownContentView
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

### Potential Improvements for Next Iteration

1. **Error Handling**
   - Add retry logic for Claude CLI connection failures
   - Better error messages when claude binary is not found or auth fails
   - Consider showing a user-friendly alert dialog for errors instead of just logging

2. **File Browser**
   - Add file watching/refresh when files change externally (e.g., when Claude creates files)
   - Consider adding file preview functionality
   - Add context menu for files (copy path, reveal in Finder, etc.)

3. **Performance**
   - The file browser loads synchronously on every path change - could benefit from caching
   - Large file lists could be slow - consider pagination or virtualization

4. **Session Management**
   - Consider persisting chat history between app launches
   - Add ability to rename sessions
   - Export chat history feature

5. **Testing**
   - No unit tests currently exist - consider adding tests for:
     - ClaudeOutputParser JSON parsing
     - ChatSession message handling
     - File browser path navigation logic

6. **Code Quality**
   - Some views in ChatView.swift are getting large (915 lines) - consider splitting into separate files
   - FileBrowserView could be moved to its own file

## Build Status
✅ Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O
