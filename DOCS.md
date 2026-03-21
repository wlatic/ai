# ai-launcher

A tmux-native session manager for Claude Code. Like Chrome's session restore for AI terminals — SSH in, see all your sessions, pick one, you're back.

## The Problem

When running Claude Code on a server via SSH:
- Closing your laptop kills the terminal but the AI keeps working
- You lose track of which conversations are running where
- Reconnecting means remembering tmux session names
- Old conversations are hard to find and resume
- Sessions accumulate unnamed, unmanaged

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
  [6] failchain-project-work         — 7h ago, fresh, 123KB

  (2 idle session(s) — use [c] to clean up)

  [n] New session   [a] Browse all conversations
  [r] Rename        [c] Cleanup   [q] Quit

  Pick:
```

**Active** = tmux sessions with claude running right now. Shows conversation name, age, context health (compaction count), and `[open]` if already attached in another tab. Pick a number → instant reconnect.

**Recent** = past conversations not currently running, sorted by size. Pick a number → creates tmux session, resumes that conversation.

**[a] Browse all** = full list of all your conversations with sort toggle (size / recent). Only shows YOUR conversations, filters out subagent/worker sessions.

**[n] New** = asks mode (normal/danger), launches fresh claude in a new tmux session.

## Commands

```
ai              Interactive session picker
ai danger       Quick-launch new session (danger mode, skip permissions)
ai normal       Quick-launch new session (normal mode)
ai --help       Usage info
```

Works from any user — if `/etc/ai-agent.conf` exists with `user=claude`, running `ai` as root auto-switches to the correct user.

## Architecture

### Files

| File | Language | Purpose |
|------|----------|---------|
| `bin/ai` | Bash | Session picker, tmux management, reconnect |
| `bin/janitor` | Bash | Background AI agent for housekeeping |
| `bin/recent-conversations` | Python | List conversations with names, ages, health, sizes |
| `bin/name-conversations` | Python | Sidecar name storage for conversation JSONL files |
| `bin/start-claude-sessions.sh` | Bash | Boot script — creates system sessions + starts janitor |
| `bin/ai-agent.conf.example` | Config | Template for `/etc/ai-agent.conf` |

### The Janitor

An AI-powered background agent running in its own tmux session, looping every 5 minutes:

**Task 1: Kill idle sessions** — Sessions with just a bash shell and no real process get cleaned up.

**Task 2: Name sessions** — New sessions get auto-generated names like `claude-0316`. The janitor reads the tmux pane content, asks haiku what the conversation is about, and renames the session to something meaningful (e.g. `fleetctl-api-design`). Names once, then leaves it alone.

**Task 3: Name conversation files** — Conversation JSONL files need display names for the "Recent conversations" and "Browse all" sections. The janitor batch-names all unnamed conversations in a single haiku API call.

**Task 4: Sync names** — For sessions launched with `--resume`, syncs the tmux session name to match the conversation's sidecar name.

**Task 5: Ghost detection** — Sessions where claude is running but the pane is empty (< 3 lines of content) get renamed to `unused-N`, then killed on the next cycle.

**Safety:**
- Protected sessions (janitor, dev, admin, brain, monitor) are never touched
- Safety floor prevents killing all non-system sessions at once
- Ghost detection checks actual pane content, not JSONL existence
- `--no-session-persistence` on all haiku calls prevents polluting the conversation list
- Named sessions tracked in `/tmp/janitor-named-sessions` — rename once, then leave alone
- Self-healing via cron (`*/10 * * * *`) restarts janitor if it dies

### Context Health

The picker shows compaction count for each conversation:
- **fresh** — no compaction, full context integrity
- **compacted 1x** — compressed once, some drift risk
- **compacted 2x+ — consider new session** — high drift risk, instructions may have degraded

Reads `compact_boundary` markers from conversation JSONL files.

### Conversation ID Mapping

Claude Code has two different ID systems:
- **Session ID** (in `/home/claude/.claude/sessions/PID.json`) — tracks the running process
- **Conversation ID** (JSONL filename) — the actual conversation data

For `--resume` sessions, the conversation ID is in `/proc/PID/cmdline`. For `--continue` sessions, the IDs don't match and we can't reliably map them. The janitor handles these via pane content reading.

### Terminal Titles

Sets `AI| <keyword>` as the terminal title via escape sequence before tmux attach. Extracts the first meaningful word from the session name (skipping generic words like api, project, rewrite).

## User Workflow

1. SSH into server (from any user)
2. Type `ai` — see all sessions
3. Pick a number to reconnect, or `[n]` for new
4. Work with claude
5. Say "detach" — claude runs `tmux detach-client`, back to SSH
6. Close laptop — everything stays alive
7. Come back, type `ai` — sessions still there

## Configuration

### `/etc/ai-agent.conf`
```ini
user=claude
project_dir=/mnt/zfs/claude/system
```

### System-wide access
```bash
ln -s /path/to/bin/ai /usr/local/bin/ai
```

### Crontab
```
*/10 * * * * /home/claude/bin/janitor >> /path/to/logs/janitor-cron.log 2>&1
```

## Key Design Decisions

1. **tmux is invisible** — users never type tmux commands, `ai` handles everything
2. **Names come from content** — the janitor reads what's on screen, not metadata
3. **One rename, then leave it** — avoids the rename loop that crashed sessions
4. **Pane content > JSONL mapping** — the `--continue` ID mismatch can't be solved, so we read the screen
5. **Batch API calls** — one haiku call names all conversations, not one per conversation
6. **`--no-session-persistence`** — janitor's haiku calls don't create garbage conversation files
7. **Filter subagents** — browse list only shows user-initiated conversations

## Standalone Repo Potential

This could be a standalone tool for anyone running Claude Code on a server. Would need:
- Remove hardcoded paths (`/mnt/zfs/claude/system`, `/home/claude/.claude/...`)
- Make `recent-conversations` and `name-conversations` discover the project dir dynamically
- Package as a single install script
- Documentation for setup (tmux, cron, `/etc/ai-agent.conf`)
- The janitor could be optional (just the `ai` picker is useful on its own)

## Team Structure

- **implementer** (subagent_type: general-purpose, isolation: worktree) — script changes, new features
- **tester** (subagent_type: general-purpose, isolation: worktree) — validation, edge case review
