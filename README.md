# ai — Session Manager for Claude Code

A tmux-native session manager for running Claude Code on servers. Like Chrome's session restore — SSH in, see all your sessions, pick one, you're back.

## The Problem

When running Claude Code on a server via SSH:
- Closing your laptop kills the terminal but the AI keeps working
- You lose track of which conversations are running where
- Reconnecting means remembering tmux session names
- Old conversations are hard to find and resume
- Sessions accumulate unnamed and unmanaged

## The Solution

One command: `ai`

```
┌─────────────────────────────┐
│   Claude Code Sessions      │
└─────────────────────────────┘

  Active:
  [1] api-paper                      — 7d ago, fresh [open]
  [2] litezfs-failchain-code         — 1h ago, compacted 1x
  [3] fleetctl-project               — 30m ago, fresh

  Recent conversations:
  [4] frigate-video-decode           — 18h ago, compacted 1x, 2.8MB
  [5] recursive-drift-review         — 7d ago, fresh, 1.0MB

  [n] New session   [a] Browse all conversations
  [r] Rename        [c] Cleanup   [q] Quit
```

- **Pick a number** → instant reconnect to running sessions or resume old conversations
- **[n]** → new session with mode selection (normal/danger)
- **[a]** → browse all conversations with sort toggle (size/recent)
- **Context health** → shows compaction count (fresh / compacted 1x / consider new session)
- **[open]** tag → shows which sessions are already attached in other terminal tabs
- **Terminal titles** → sets `AI| keyword` in your terminal tab

## Quick Start

```bash
# Clone
git clone https://github.com/wlatic/ai.git
cd ai

# Install
./install.sh

# Use
ai              # Session picker
ai danger       # Quick-launch (danger mode)
ai normal       # Quick-launch (normal mode)
```

## Requirements

- Linux server with SSH access
- [Claude Code](https://claude.ai/claude-code) installed
- tmux
- Python 3.6+
- bash 4+

## How It Works

### Session Picker (`ai`)
Shows active tmux sessions running claude and recent conversations. Pick a number to reconnect instantly or resume a past conversation in a new tmux session.

### The Janitor
An AI-powered background agent that runs every 5 minutes:
1. **Kills idle sessions** — bash-only shells with no real process
2. **Names sessions** — reads pane content, asks Claude haiku to generate a short name
3. **Names conversations** — batch-names all unnamed conversation files in one API call
4. **Syncs names** — keeps tmux session names aligned with conversation names
5. **Ghost detection** — kills sessions with claude running but empty pane (nobody ever talked to it)

Self-healing via cron — restarts automatically if it crashes.

### Context Health
Reads `compact_boundary` markers from conversation JSONL files to show how many times context has been compressed:
- **fresh** — full context integrity
- **compacted 1x** — some drift risk
- **compacted 2x+** — instructions may have degraded, consider starting a new session

### Multi-User Support
Add `/etc/ai-agent.conf`:
```ini
user=claude
project_dir=/home/claude/my-project
```
Now any user (including root) can run `ai` and it auto-switches to the correct user.

## Files

| File | Purpose |
|------|---------|
| `bin/ai` | Session picker and tmux management |
| `bin/janitor` | Background AI housekeeping agent |
| `bin/recent-conversations` | List conversations with names, ages, health |
| `bin/name-conversations` | Sidecar name storage for conversations |
| `install.sh` | Installation script |
| `ai-agent.conf.example` | Template for `/etc/ai-agent.conf` |

## Configuration

### Protected Sessions
Sessions that the janitor will never touch (edit `PROTECTED_SESSIONS` in `bin/janitor`):
```
janitor|dev|admin|brain|monitor
```

### Janitor Interval
Default: 5 minutes (edit `INTERVAL` in `bin/janitor`)

### Terminal Titles
Sets `AI| keyword` via escape sequence before tmux attach. Works with terminals that respect OSC title sequences. For XPipe/Windows Terminal, you may need to configure the terminal profile to not suppress application titles.

## License

MIT
