# myfirsttool — Claude Code Plugin

All-in-one Claude Code plugin providing file protection, auto-linting, audit logging, desktop notifications, and a deploy-readiness checker.

## Features

### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| **pre-write-lint.sh** | PreToolUse (Write/Edit) | Blocks writes to lockfiles, `.env`, CI configs, and Dockerfiles |
| **post-write-lint.sh** | PostToolUse (Write/Edit) | Auto-formats files using the appropriate tool (prettier, eslint, ruff, rustfmt, gofmt, etc.) |
| **audit-logger.sh** | PostToolUse (Bash) | Logs every bash command as JSONL; flags suspicious commands to alerts log |
| **notify-done.sh** | Stop / Notification / SubagentStop | Plays a sound and sends a desktop notification when Claude finishes |

### Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **deploy-check** | `/deploy-check` | Pre-deployment checklist: tests, diffs, secrets, debug statements, TODOs, changelog |

## Installation

### As a Shared Plugin (claude.ai upload)

1. Zip the `myfirsttool/` directory:
   ```bash
   cd .claude/plugins
   zip -r myfirsttool.zip myfirsttool/
   ```
2. Upload `myfirsttool.zip` on the Claude Code plugins page.

### Manual Installation

1. Copy the `myfirsttool/` folder into your project's `.claude/plugins/` directory:
   ```bash
   cp -r myfirsttool /path/to/your/project/.claude/plugins/
   ```

2. Ensure scripts are executable:
   ```bash
   chmod +x .claude/plugins/myfirsttool/hooks/*.sh
   ```

3. **Required dependencies** (install those you need):
   - `jq` — required for all hooks (JSON parsing)
   - `prettier` / `eslint` — JS/TS formatting (prefers project-local `node_modules/.bin/`)
   - `ruff` or `black` + `isort` — Python formatting
   - `rustfmt` — Rust formatting
   - `gofmt` + `goimports` — Go formatting
   - `notify-send` (Linux) or `terminal-notifier` (macOS) — desktop notifications

## File Structure

```
myfirsttool/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   ├── hooks.json           # Hook definitions
│   ├── pre-write-lint.sh    # Block writes to protected files
│   ├── post-write-lint.sh   # Auto-format after writes
│   ├── audit-logger.sh      # Log all bash commands
│   └── notify-done.sh       # Sound + desktop notification
├── skills/
│   └── deploy-check/
│       └── SKILL.md         # Deployment checklist skill
├── sounds/                  # Custom sound files (optional)
│   └── (place .wav files here: stop.wav, notification.wav, subagent.wav)
├── logs/                    # Auto-generated logs
│   ├── audit.jsonl          # All bash command log
│   ├── alerts.jsonl         # Suspicious command alerts
│   └── lint.log             # Linting activity log
└── README.md
```

## Custom Sounds

Place `.wav` files in the `sounds/` directory to override system sounds:

- `stop.wav` — played when Claude finishes a task
- `notification.wav` — played for notifications
- `subagent.wav` — played when a subagent completes

If these files are missing, the plugin falls back to OS system sounds:
- **macOS**: Hero.aiff, Glass.aiff, Ping.aiff
- **Linux**: freedesktop sound theme
- **Windows**: System sounds (Asterisk, Exclamation, Hand)

## Logs

All logs are written to the `logs/` directory:

- **audit.jsonl** — every bash command with timestamp, session ID, and working directory
- **alerts.jsonl** — flagged suspicious commands (rm -rf /, curl|bash, chmod 777, etc.)
- **lint.log** — all auto-formatting activity

## Configuration

The plugin uses these environment variables:
- `CLAUDE_PROJECT_DIR` — project root (set automatically by Claude Code)
- `CLAUDE_SESSION_ID` — current session ID (set automatically by Claude Code)
