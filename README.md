# Ask Claude - Finder Integration

A native macOS app that adds "Ask Claude" to Finder's right-click context menu, allowing you to interact with Claude Code directly from any folder.

> **Disclaimer:** This is an unofficial community project and is not affiliated with, endorsed by, or sponsored by Anthropic. "Claude" is a trademark of Anthropic.

![AskClaude Screenshot](screenshot.png)

## Features

- Right-click any folder in Finder → "Ask Claude"
- Chat-style UI with markdown rendering and syntax highlighting
- Multiple concurrent sessions per workspace
- Model selection (Haiku, Sonnet, Opus)
- File browser with drag & drop support
- Permission approval UI for Claude tool use
- Runs Claude Code in the selected folder's context

## Requirements

- macOS 14.0 or later
- [Claude Code CLI](https://claude.ai/download) installed and signed in

## Installation

### Quick Install (Recommended)

Download the latest release and run:

```bash
curl -sL https://raw.githubusercontent.com/andropar/AskClaude/main/scripts/install.sh | bash
```

### Manual Install

1. Download `AskClaude.zip` from the [latest release](https://github.com/andropar/AskClaude/releases)
2. Extract and move `AskClaude.app` to `/Applications`
3. Right-click the app → Open (to bypass Gatekeeper on first run)
4. The Finder extension will be enabled automatically

If the extension doesn't appear, run:
```bash
pluginkit -e use -i com.askclaude.app.FinderSyncExtension
```

### Build from Source

1. Clone the repository
2. Open `AskClaude/AskClaude.xcodeproj` in Xcode
3. Select your Development Team in both targets:
   - AskClaude (main app)
   - FinderSyncExtension
4. Build and run (⌘R)

## Usage

1. **Start the app** - Open AskClaude from /Applications (keeps it running in background)
2. **Right-click any folder** in Finder
3. **Click "Ask Claude"** in the context menu
4. **Chat with Claude** in the context of that folder

### Settings

Go to **AskClaude → Settings** (⌘,) to configure:

- **Auto-approve permissions**: Skip permission prompts for tool use (use with caution)

### Keyboard Shortcuts

- `⌘+` / `⌘-` - Increase/decrease text size
- `⌘0` - Reset text size
- `⌘N` - New session

## Troubleshooting

### Extension Not Appearing in Finder

On macOS Sequoia (15.0+), Finder extensions may not appear in the System Settings GUI. Use:

```bash
# Enable the extension manually
pluginkit -e use -i com.askclaude.app.FinderSyncExtension

# Verify it's registered
pluginkit -m -i com.askclaude.app.FinderSyncExtension
```

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
├── Shared/                       # Shared code
└── scripts/                      # Build & install scripts
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT - see [LICENSE](../LICENSE)
