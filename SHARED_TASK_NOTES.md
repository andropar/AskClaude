# Shared Task Notes

## Recent Work (2025-12-31)

### Latest Progress - UI Improvements (NEWEST)
1. **Error display for users** (ChatView.swift:35-46)
   - Wired up existing ErrorBanner component that was defined but never used
   - Now displays session errors below the header bar with dismiss button
   - Animated appearance/disappearance with spring transitions

2. **Session renaming** (ChatSession.swift:45-51, SessionSidebar.swift)
   - Added `customName` property to ChatSession with `displayName` computed property
   - Right-click on session in sidebar now shows "Rename..." option
   - Inline text field editing with Enter to confirm, Escape to cancel
   - Header bar shows displayName with tooltip for full folder path
   - If renamed to match folder name, custom name is cleared

### Testing Infrastructure (IN PROGRESS)
- ✅ ClaudeOutputParser tests created (21 test cases) in AskClaudeTests/ClaudeOutputParserTests.swift
- ⏳ Add test target to Xcode project (manual step - see setup_tests.sh)
- 📝 TODO: Add tests for ChatSession message handling
- 📝 TODO: Add tests for ClaudeProcessManager

### Priority Improvements for Next Iteration

1. **Code Organization** - Large files need splitting
   - MarkdownContentView.swift: 1,186 lines (extract ImageBlockView, FilePreviewView, etc.)
   - ChatView.swift: ~930 lines (extract FileBrowserView, PermissionDialog, etc.)
   - ContentView.swift: 501 lines (consider splitting sidebar)

2. **Session Management**
   - Chat history persistence exists (ChatPersistence.swift) but sessions always start fresh
   - Could allow option to restore previous session for a folder
   - Export chat history feature

3. **File Browser Improvements**
   - Add file watching/refresh when files change externally
   - Add context menu for files (copy path, reveal in Finder)
   - Add caching to prevent synchronous reloads on every path change

4. **Error Handling - Additional**
   - Add retry logic for Claude CLI connection failures
   - More specific error messages for auth failures vs process crashes

## Build Status
✅ Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O
