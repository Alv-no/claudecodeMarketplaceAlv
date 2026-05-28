#!/bin/bash
# post-write-lint.sh — Auto-format files after Write/Edit based on file type
# Reads hook context JSON from stdin. Always exits 0.

set -uo pipefail

INPUT="$(cat)"
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-.}"
LOG_DIR="$PLUGIN_DIR/logs"
mkdir -p "$LOG_DIR"
LINT_LOG="$LOG_DIR/lint.log"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LINT_LOG"
}

# Extract file path
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXTENSION="${FILE_PATH##*.}"
EXTENSION_LOWER="$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Helper: find local or global binary
find_bin() {
  local name="$1"
  local local_bin="$PROJECT_DIR/node_modules/.bin/$name"
  if [ -x "$local_bin" ]; then
    echo "$local_bin"
  elif command -v "$name" &>/dev/null; then
    echo "$name"
  fi
}

format_js_ts() {
  local prettier
  prettier="$(find_bin prettier)"
  if [ -n "$prettier" ]; then
    log "Running prettier on $FILE_PATH"
    "$prettier" --write "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "prettier failed for $FILE_PATH"
  fi

  local eslint
  eslint="$(find_bin eslint)"
  if [ -n "$eslint" ]; then
    log "Running eslint --fix on $FILE_PATH"
    "$eslint" --fix "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "eslint --fix failed for $FILE_PATH"
  fi
}

format_python() {
  if command -v ruff &>/dev/null; then
    log "Running ruff format on $FILE_PATH"
    ruff format "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "ruff format failed for $FILE_PATH"
    log "Running ruff check --fix on $FILE_PATH"
    ruff check --fix "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "ruff check failed for $FILE_PATH"
  else
    if command -v black &>/dev/null; then
      log "Running black on $FILE_PATH"
      black "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "black failed for $FILE_PATH"
    fi
    if command -v isort &>/dev/null; then
      log "Running isort on $FILE_PATH"
      isort "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "isort failed for $FILE_PATH"
    fi
  fi
}

format_rust() {
  if command -v rustfmt &>/dev/null; then
    log "Running rustfmt on $FILE_PATH"
    rustfmt "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "rustfmt failed for $FILE_PATH"
  fi
}

format_go() {
  if command -v gofmt &>/dev/null; then
    log "Running gofmt on $FILE_PATH"
    gofmt -w "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "gofmt failed for $FILE_PATH"
  fi
  if command -v goimports &>/dev/null; then
    log "Running goimports on $FILE_PATH"
    goimports -w "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "goimports failed for $FILE_PATH"
  fi
}

format_json() {
  local prettier
  prettier="$(find_bin prettier)"
  if [ -n "$prettier" ]; then
    log "Running prettier on $FILE_PATH"
    "$prettier" --write "$FILE_PATH" >> "$LINT_LOG" 2>&1 || log "prettier failed for $FILE_PATH"
  elif command -v jq &>/dev/null; then
    log "Running jq format on $FILE_PATH"
    local tmp
    tmp="$(mktemp)"
    if jq '.' "$FILE_PATH" > "$tmp" 2>> "$LINT_LOG"; then
      mv "$tmp" "$FILE_PATH"
    else
      rm -f "$tmp"
      log "jq format failed for $FILE_PATH"
    fi
  fi
}

case "$EXTENSION_LOWER" in
  js|jsx|ts|tsx|mjs|cjs|mts|cts)
    format_js_ts
    ;;
  py|pyi)
    format_python
    ;;
  rs)
    format_rust
    ;;
  go)
    format_go
    ;;
  json|jsonc)
    format_json
    ;;
  *)
    log "No formatter configured for extension .$EXTENSION_LOWER ($FILE_PATH)"
    ;;
esac

exit 0
