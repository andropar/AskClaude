# Shared Task Notes

## Recent Work (2025-12-31)

### Latest Progress - Code Refactoring (MarkdownContentView)
**Extracted components from MarkdownContentView.swift** (1,186 → 418 lines)
- Created 3 new files to improve code organization:
  1. **MediaViews.swift** (~230 lines) - ImageBlockView, VideoPlayerView, PDFPreviewView
  2. **FilePreviewView.swift** (~280 lines) - File preview component with CSV, images, videos, PDFs
  3. **MarkdownComponents.swift** (~190 lines) - TableView, ContentBlock enum, InlineMarkdownParser
- MarkdownContentView.swift now contains only the main view and markdown parsing logic
- All files added to Xcode project and build verified

### Earlier Progress - Testing Infrastructure (2025-12-28)
**Test files created for ClaudeOutputParser** (AskClaudeTests/ClaudeOutputParserTests.swift)
- Created comprehensive unit test suite with 21 test cases
- Tests ready to be added to Xcode project
- **Next step**: Add test target to Xcode project and run tests (see setup_tests.sh)

### Bug Fixes (Previous Iterations)
- NotificationCenter observer memory leaks (ChatSession, AppDelegate)
- Streaming message state bugs in stop()/result handlers
- CSV file size limit, CFMessagePort leak
- Race condition in stdin pipe writes
- Session state management cleanup
- Memory safety (buffer limits) in ClaudeProcessManager
- Timer memory leaks, file handle leaks

## Priority Improvements for Next Iteration

1. **Testing Infrastructure** (IN PROGRESS)
   - ✅ ClaudeOutputParser tests created (21 test cases)
   - ⏳ Add test target to Xcode project (manual step - see setup_tests.sh)
   - 📝 TODO: Add tests for ChatSession message handling
   - 📝 TODO: Add tests for ClaudeProcessManager

2. **Code Organization** (PARTIALLY COMPLETE)
   - ✅ MarkdownContentView.swift refactored (1,186 → 418 lines)
   - ⏳ ChatView.swift: 924 lines (extract FileBrowserView, PermissionDialog, etc.)
   - ⏳ ContentView.swift: 501 lines (consider splitting sidebar)

3. **Error Handling**
   - Error messages only logged, not shown to users
   - Add user-facing alert dialogs for errors
   - Add retry logic for Claude CLI connection failures

4. **Session Management**
   - Persist chat history between app launches
   - Add ability to rename sessions
   - Export chat history feature

5. **File Browser Improvements**
   - Add file watching/refresh when files change externally
   - Add context menu for files (copy path, reveal in Finder)
   - Add caching to prevent synchronous reloads

## Build Status
✅ Project builds successfully with no errors or warnings

## Architecture Notes
- Main app: SwiftUI-based chat interface
- Finder extension: Context menu integration
- Communication: URL scheme (askclaude://) between extension and main app
- Claude CLI: Runs as subprocess with stream-json I/O

## Views Directory Structure
```
Views/
├── ContentView.swift         (501 lines - main app view)
├── ChatView.swift            (924 lines - chat interface)
├── MessageBubble.swift       (message display)
├── MarkdownContentView.swift (418 lines - markdown rendering)
├── MarkdownComponents.swift  (TableView, ContentBlock, InlineMarkdownParser)
├── MediaViews.swift          (ImageBlockView, VideoPlayerView, PDFPreviewView)
├── FilePreviewView.swift     (file content previews)
├── CodeBlockView.swift       (syntax-highlighted code blocks)
├── InputBar.swift            (message input)
├── ThinkingIndicator.swift   (loading states)
└── SessionSidebar.swift      (session list)
```
