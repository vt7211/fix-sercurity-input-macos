#!/usr/bin/env bash
# Quick fix Vietnamese typing (EVKey) — safe defaults, ~5s
set -euo pipefail
echo "=== FIX_VI_TYPING $(date '+%H:%M:%S') ==="

secure_pid() {
  ioreg -l -w 0 2>/dev/null | python3 -c '
import sys,re
raw=sys.stdin.buffer.read().decode("utf-8","replace")
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", raw)
print(m.group(1) if m else "0")
' 2>/dev/null || echo 0
}

# 1) iTerm Secure Keyboard Entry OFF (persistent)
defaults write com.googlecode.iterm2 SecureInput -bool false 2>/dev/null || true
defaults write com.googlecode.iterm2 "Secure Input" -bool false 2>/dev/null || true

# 2) Carbon nudge (helps when OUR session still holds refs)
python3 - <<'PY' 2>/dev/null || true
import ctypes
lib = ctypes.CDLL("/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox")
for _ in range(8):
    lib.EnableSecureEventInput()
    lib.DisableSecureEventInput()
for _ in range(16):
    lib.DisableSecureEventInput()
PY

# 3) Logi event-tap rival (kill + unload launch agent — killall alone bị launchd kéo lại)
launchctl bootout "gui/$(id -u)" /Library/LaunchAgents/com.logitech.manager.daemon.plist 2>/dev/null || true
killall LogiMgrDaemon 2>/dev/null && echo "OK stopped LogiMgrDaemon" || echo "skip LogiMgrDaemon"
killall "Logi Options" 2>/dev/null || true

# 4) Restart EVKey only if đang chạy / được yêu cầu (--evkey)
WANT_EVKEY=0
[[ "${1:-}" == "--evkey" || "${2:-}" == "--evkey" ]] && WANT_EVKEY=1
if pgrep -x EVKey >/dev/null 2>&1 || pgrep -f '/EVKeyMac.app/Contents/MacOS/EVKey' >/dev/null 2>&1; then
  WANT_EVKEY=1
fi
if (( WANT_EVKEY )); then
  killall EVKey 2>/dev/null || true
  sleep 0.8
  open -a EVKeyMac
  sleep 1.2
  pgrep -x EVKey >/dev/null && echo "EVKEY=yes" || echo "EVKEY=no — mở EVKeyMac thủ công"
else
  echo "EVKEY=skip (dùng Telex hệ thống — truyền --evkey nếu cần)"
fi

PID=$(secure_pid)
if [[ "$PID" != "0" && -n "$PID" ]]; then
  if ps -p "$PID" >/dev/null 2>&1; then
    COMM=$(ps -p "$PID" -o comm= 2>/dev/null || echo unknown)
    echo "SECURE_INPUT still ACTIVE pid=$PID ($COMM)"
    echo "HINT: nha-secure-input  |  hoặc Ctrl+Cmd+Q rồi mở khóa (không cần Restart)."
  else
    echo "SECURE_INPUT STUCK zombie pid=$PID"
    echo "HINT: nha-secure-input  |  hoặc Ctrl+Cmd+Q rồi mở khóa."
  fi
else
  echo "SECURE_INPUT=off OK"
fi

# Optional: lock screen to clear Secure Input held by loginwindow/other app
if [[ "${1:-}" == "--lock" || "${2:-}" == "--lock" ]]; then
  echo "Locking screen now — unlock bằng mật khẩu/Touch ID..."
  python3 - <<'PY' 2>/dev/null || osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}'
import ctypes
ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login").SACLockScreenImmediate()
PY
fi

echo "=== DONE — thử gõ trong TextEdit ==="
