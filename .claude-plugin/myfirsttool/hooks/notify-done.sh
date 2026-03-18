#!/bin/bash
# notify-done.sh — Play sound + desktop notification on Stop/Notification/SubagentStop
# Usage: notify-done.sh <type>  where type is: stop|notification|subagent
# Reads hook context JSON from stdin. Always exits 0.

set -uo pipefail

EVENT_TYPE="${1:-notification}"
INPUT="$(cat)"
PLUGIN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/plugins/myfirsttool"
SOUNDS_DIR="$PLUGIN_DIR/sounds"

# Extract session directory from context
SESSION_DIR="$(echo "$INPUT" | jq -r '.session_id // .session_dir // "unknown"' 2>/dev/null || echo "unknown")"

# Determine title and message
case "$EVENT_TYPE" in
  stop)
    TITLE="Claude Code — Done"
    MESSAGE="Task completed. Session: $SESSION_DIR"
    ;;
  subagent)
    TITLE="Claude Code — Subagent Done"
    MESSAGE="Subagent finished. Session: $SESSION_DIR"
    ;;
  notification|*)
    TITLE="Claude Code — Notification"
    MESSAGE="Attention needed. Session: $SESSION_DIR"
    ;;
esac

# --- Sound Playback ---

play_sound() {
  local sound_file="$1"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay "$sound_file" &>/dev/null &
  elif [[ "$OSTYPE" == "linux"* ]]; then
    if command -v paplay &>/dev/null; then
      paplay "$sound_file" &>/dev/null &
    elif command -v aplay &>/dev/null; then
      aplay "$sound_file" &>/dev/null &
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    powershell.exe -NoProfile -Command "(New-Object Media.SoundPlayer '$sound_file').PlaySync()" &>/dev/null &
  fi
}

play_system_sound() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local snd
    case "$EVENT_TYPE" in
      stop)         snd="/System/Library/Sounds/Hero.aiff" ;;
      subagent)     snd="/System/Library/Sounds/Ping.aiff" ;;
      notification) snd="/System/Library/Sounds/Glass.aiff" ;;
    esac
    [ -f "$snd" ] && afplay "$snd" &>/dev/null &
  elif [[ "$OSTYPE" == "linux"* ]]; then
    # Try freedesktop sounds
    local snd="/usr/share/sounds/freedesktop/stereo/complete.oga"
    case "$EVENT_TYPE" in
      stop)         snd="/usr/share/sounds/freedesktop/stereo/complete.oga" ;;
      subagent)     snd="/usr/share/sounds/freedesktop/stereo/message.oga" ;;
      notification) snd="/usr/share/sounds/freedesktop/stereo/bell.oga" ;;
    esac
    if [ -f "$snd" ]; then
      if command -v paplay &>/dev/null; then
        paplay "$snd" &>/dev/null &
      elif command -v aplay &>/dev/null; then
        aplay "$snd" &>/dev/null &
      fi
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Use Windows system sounds via PowerShell
    local snd_type
    case "$EVENT_TYPE" in
      stop)         snd_type="Asterisk" ;;
      subagent)     snd_type="Exclamation" ;;
      notification) snd_type="Hand" ;;
    esac
    powershell.exe -NoProfile -Command "[System.Media.SystemSounds]::${snd_type}.Play()" &>/dev/null &
  fi
}

# Try custom sound first, fall back to system sounds
CUSTOM_SOUND="$SOUNDS_DIR/${EVENT_TYPE}.wav"
if [ -f "$CUSTOM_SOUND" ]; then
  play_sound "$CUSTOM_SOUND"
else
  play_system_sound
fi

# --- Desktop Notification ---

send_notification() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Prefer terminal-notifier, fall back to osascript
    if command -v terminal-notifier &>/dev/null; then
      terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound default &>/dev/null &
    else
      osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" &>/dev/null &
    fi
  elif [[ "$OSTYPE" == "linux"* ]]; then
    if command -v notify-send &>/dev/null; then
      notify-send "$TITLE" "$MESSAGE" --expire-time=5000 &>/dev/null &
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    powershell.exe -NoProfile -Command "
      Add-Type -AssemblyName System.Windows.Forms
      \$notify = New-Object System.Windows.Forms.NotifyIcon
      \$notify.Icon = [System.Drawing.SystemIcons]::Information
      \$notify.BalloonTipTitle = '$TITLE'
      \$notify.BalloonTipText = '$MESSAGE'
      \$notify.Visible = \$true
      \$notify.ShowBalloonTip(5000)
      Start-Sleep -Seconds 6
      \$notify.Dispose()
    " &>/dev/null &
  fi
}

send_notification

exit 0
