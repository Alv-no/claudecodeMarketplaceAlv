#!/bin/bash
# audit-logger.sh — Log all Bash commands as JSONL, flag suspicious commands
# Reads hook context JSON from stdin. Always exits 0.

set -uo pipefail

INPUT="$(cat)"
PLUGIN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/plugins/myfirsttool"
LOG_DIR="$PLUGIN_DIR/logs"
mkdir -p "$LOG_DIR"

AUDIT_LOG="$LOG_DIR/audit.jsonl"
ALERTS_LOG="$LOG_DIR/alerts.jsonl"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
WORKING_DIR="$(pwd)"

# Extract the command from the tool input
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Escape the command for safe JSON embedding
COMMAND_ESCAPED="$(echo "$COMMAND" | jq -Rs '.' 2>/dev/null || echo "\"$COMMAND\"")"

# Write audit log entry
cat >> "$AUDIT_LOG" <<JSONL
{"timestamp":"$TIMESTAMP","command":$COMMAND_ESCAPED,"session_id":"$SESSION_ID","working_dir":"$WORKING_DIR"}
JSONL

# Check for suspicious commands
SUSPICIOUS=false
ALERT_REASON=""

# rm -rf / or rm -rf /*
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|--force\s+)*(\/\s*$|\/\*|~\/\.\*)'; then
  SUSPICIOUS=true
  ALERT_REASON="Dangerous recursive deletion targeting root or home"
fi

# curl piped to bash/sh
if echo "$COMMAND" | grep -qE 'curl\s.*\|\s*(ba)?sh|wget\s.*\|\s*(ba)?sh'; then
  SUSPICIOUS=true
  ALERT_REASON="Remote code execution: piping download to shell"
fi

# chmod 777
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
  SUSPICIOUS=true
  ALERT_REASON="Overly permissive chmod 777"
fi

# eval with variables or remote content
if echo "$COMMAND" | grep -qE 'eval\s+"\$|eval\s+\$\('; then
  SUSPICIOUS=true
  ALERT_REASON="Eval with dynamic content"
fi

# mkfs / dd to disk devices
if echo "$COMMAND" | grep -qE 'mkfs\.|dd\s+.*of=/dev/'; then
  SUSPICIOUS=true
  ALERT_REASON="Disk-level destructive operation"
fi

# Reverse shells
if echo "$COMMAND" | grep -qE '/dev/tcp/|nc\s.*-e|ncat\s.*-e|bash\s+-i\s+>&'; then
  SUSPICIOUS=true
  ALERT_REASON="Potential reverse shell"
fi

# Writing to /etc/passwd, /etc/shadow, or sudoers
if echo "$COMMAND" | grep -qE '>\s*/etc/(passwd|shadow|sudoers)'; then
  SUSPICIOUS=true
  ALERT_REASON="Attempting to modify critical system files"
fi

if [ "$SUSPICIOUS" = true ]; then
  cat >> "$ALERTS_LOG" <<JSONL
{"timestamp":"$TIMESTAMP","command":$COMMAND_ESCAPED,"session_id":"$SESSION_ID","working_dir":"$WORKING_DIR","reason":"$ALERT_REASON"}
JSONL
fi

exit 0
