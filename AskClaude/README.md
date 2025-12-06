# AskClaude - Finder Integration

A native macOS app that adds "Ask Claude" to Finder's right-click context menu, allowing you to interact with Claude Code directly from any folder.

> **Disclaimer:** This is an unofficial community project and is not affiliated with, endorsed by, or sponsored by Anthropic. "Claude" is a trademark of Anthropic.

## Features

- Right-click any folder in Finder → "Ask Claude"
- Chat-style UI with markdown rendering and syntax highlighting
- Multiple concurrent sessions per workspace
- Model selection (Haiku, Sonnet, Opus)
- File browser with drag & drop support
- Permission approval UI for Claude tool use

## Requirements

- macOS 14.0 or later
- [Claude Code CLI](https://claude.ai/download) installed and signed in
- Xcode 15+ (for building)

## Installation

Due to macOS security requirements, Finder extensions must be code-signed. This means you need to build the app yourself using Xcode (which will sign it with your free Apple ID).

### Quick Build (Terminal)

```bash
# Clone the repo
git clone https://github.com/andropar/AskClaude.git
cd AskClaude/AskClaude

# Build and install (requires Xcode)
xcodebuild -project AskClaude.xcodeproj -scheme AskClaude -configuration Release archive -archivePath build/AskClaude.xcarchive
cp -R build/AskClaude.xcarchive/Products/Applications/AskClaude.app /Applications/

# Open the app (this registers the Finder extension)
open /Applications/AskClaude.app
```

### Build in Xcode (Recommended)

1. Clone the repository
2. Open `AskClaude/AskClaude.xcodeproj` in Xcode
3. Select your Development Team in both targets:
   - `AskClaude` (main app)
   - `FinderSyncExtension`
4. Build and run (⌘R)
5. The app will install and register the Finder extension automatically

## Usage

1. **Launch AskClaude** - The app runs in the background (look for the sparkle icon in the menu bar)
2. **Right-click any folder** in Finder
3. **Click "Ask Claude"** in the context menu
4. **Chat with Claude** in the context of that folder

You can close the main window - AskClaude runs in the background and will open automatically when you select "Ask Claude" from Finder.

### Settings

Go to **AskClaude → Settings** (⌘,) to configure:

- **Auto-approve permissions**: Skip permission prompts for tool use (use with caution)

### Keyboard Shortcuts

- `⌘+` / `⌘-` - Increase/decrease text size
- `⌘0` - Reset text size
- `⌘N` - New session

## Troubleshooting

### Extension Not Appearing in Finder

If the extension doesn't appear after building:

```bash
# Manually enable the extension
pluginkit -e use -i com.askclaude.app.FinderSyncExtension

# Restart Finder
killall Finder
```

On macOS Sequoia (15.0+), you may also need to enable it in:
**System Settings → Privacy & Security → Extensions → Finder Extensions**

### "Claude Code not found" Error

Make sure Claude Code CLI is installed:

```bash
# Check if claude is installed
which claude

# If not installed, visit:
# https://claude.ai/download
```

### "Not signed in" Error

Sign in to Claude Code:

```bash
claude
```

Follow the prompts to authenticate.

## Architecture

```
┌─────────────────────┐     IPC/URL      ┌──────────────────────┐
│  Finder Extension   │ ──────────────▶  │     Main App         │
│  (context menu)     │                  │  (SwiftUI chat UI)   │
└─────────────────────┘                  └──────────┬───────────┘
                                                    │
                                                    │ stdin/stdout
                                                    ▼
                                         ┌──────────────────────┐
                                         │   Claude CLI         │
                                         │   (stream-json)      │
                                         └──────────────────────┘
```

## Project Structure

```
AskClaude/
├── AskClaude/                    # Main App
│   ├── App/                      # App entry point, settings
│   ├── Views/                    # SwiftUI views
│   ├── Models/                   # Data models
│   └── Services/                 # Claude process management
├── FinderSyncExtension/          # Finder extension
└── Shared/                       # Shared code
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT - see [LICENSE](LICENSE)
