#!/usr/bin/env bash
# Watchdog: nếu Secure Input bị giữ liên tục >= STUCK_SECONDS → tự khóa màn hình.
# Không Restart. Không kill loginwindow (không an toàn).
# Cài: bash .../install-secure-input-watchdog.sh
#
# Env:
#   SECURE_INPUT_STUCK_SECONDS     mặc định 90
#   SECURE_INPUT_POST_UNLOCK_GRACE mặc định 60 — không auto-lock trong N giây sau khi SI vừa tắt
#   SECURE_INPUT_REOPEN_BARRIER    mặc định 1 — khi SI off mà barriers chết → open -a Barrier
#   SECURE_INPUT_LOCK_COOLDOWN     mặc định 120
#   SECURE_INPUT_NOTIFY_COOLDOWN   mặc định 300
set -euo pipefail

STUCK_SECONDS="${SECURE_INPUT_STUCK_SECONDS:-90}"
POST_UNLOCK_GRACE="${SECURE_INPUT_POST_UNLOCK_GRACE:-60}"
REOPEN_BARRIER="${SECURE_INPUT_REOPEN_BARRIER:-1}"
NOTIFY_COOLDOWN="${SECURE_INPUT_NOTIFY_COOLDOWN:-300}"
LOCK_COOLDOWN="${SECURE_INPUT_LOCK_COOLDOWN:-120}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/secure-input-watchdog"
STATE_FILE="$STATE_DIR/last.json"
SCHEMA_VERSION=1

mkdir -p "$STATE_DIR"

secure_pid() {
  ioreg -l -w 0 2>/dev/null | python3 -c '
import sys,re
raw=sys.stdin.buffer.read().decode("utf-8","replace")
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", raw)
print(m.group(1) if m else "0")
' 2>/dev/null || echo 0
}

screen_locked() {
  # 1 = locked, 0 = unlocked / unknown
  python3 - <<'PY' 2>/dev/null || echo 0
try:
    import Quartz
    d = Quartz.CGSessionCopyCurrentDictionary() or {}
    print(1 if d.get("CGSSessionScreenIsLocked") else 0)
except Exception:
    print(0)
PY
}

write_state() {
  local pid="$1" comm="$2" first_seen="$3" last_notify="$4" last_lock="$5" last_clear="$6" lock_failures="$7" updated="$8"
  python3 - <<PY
import json
json.dump({
  "schema_version": $SCHEMA_VERSION,
  "pid": "$pid",
  "comm": "$comm",
  "first_seen": int($first_seen),
  "last_notify": int($last_notify),
  "last_lock": int($last_lock),
  "last_clear": int($last_clear),
  "lock_failures": int($lock_failures),
  "updated": int($updated),
}, open("$STATE_FILE", "w"), indent=2)
print("", end="")
PY
}

load_state_vars() {
  # Sets: FIRST_SEEN LAST_NOTIFY LAST_LOCK LAST_CLEAR LOCK_FAILURES PREV_PID
  FIRST_SEEN=$NOW
  LAST_NOTIFY=0
  LAST_LOCK=0
  LAST_CLEAR=0
  LOCK_FAILURES=0
  PREV_PID=""
  if [[ ! -f "$STATE_FILE" ]]; then
    return
  fi
  eval "$(python3 - <<PY
import json, shlex
try:
    d = json.load(open("$STATE_FILE"))
except Exception:
    raise SystemExit(0)

def i(k, default=0):
    try:
        return int(d.get(k, default) or 0)
    except Exception:
        return default

pid = str(d.get("pid") or "")
print(f"PREV_PID={shlex.quote(pid)}")
print(f"LAST_NOTIFY={i('last_notify')}")
print(f"LAST_LOCK={i('last_lock')}")
print(f"LAST_CLEAR={i('last_clear')}")
print(f"LOCK_FAILURES={i('lock_failures')}")
if pid == "$PID" and pid not in ("", "0"):
    print(f"FIRST_SEEN={i('first_seen', $NOW)}")
else:
    print(f"FIRST_SEEN=$NOW")
PY
)" 2>/dev/null || true
}

maybe_reopen_barrier() {
  if [[ "$REOPEN_BARRIER" != "1" ]]; then
    return
  fi
  if pgrep -x barriers >/dev/null 2>&1; then
    return
  fi
  if [[ ! -d /Applications/Barrier.app ]]; then
    return
  fi
  logger -t secure-input-watchdog "SI cleared — barriers not running; open -a Barrier"
  open -a Barrier 2>/dev/null || true
  osascript -e 'display notification "Secure Input đã tắt — đã mở lại Barrier." with title "Secure Input Watchdog"' 2>/dev/null || true
}

NOW=$(date +%s)
PID=$(secure_pid)
load_state_vars

# --- SI off: ghi last_clear, optional Barrier, xóa tracking PID ---
if [[ "$PID" == "0" || -z "$PID" ]]; then
  WAS_ON=0
  if [[ -n "${PREV_PID:-}" && "$PREV_PID" != "0" && -n "$PREV_PID" ]]; then
    WAS_ON=1
  fi
  if [[ "$WAS_ON" -eq 1 ]]; then
    LAST_CLEAR=$NOW
    write_state "0" "" 0 "$LAST_NOTIFY" "$LAST_LOCK" "$LAST_CLEAR" 0 "$NOW"
    maybe_reopen_barrier
  else
    # Giữ last_clear / last_lock cho grace; không theo dõi PID
    write_state "0" "" 0 "$LAST_NOTIFY" "$LAST_LOCK" "$LAST_CLEAR" 0 "$NOW"
  fi
  exit 0
fi

COMM=$(ps -p "$PID" -o comm= 2>/dev/null || echo "zombie")
ELAPSED=$((NOW - FIRST_SEEN))

# Persist tracking (chưa lock)
write_state "$PID" "$COMM" "$FIRST_SEEN" "$LAST_NOTIFY" "$LAST_LOCK" "$LAST_CLEAR" "$LOCK_FAILURES" "$NOW"

if (( ELAPSED < STUCK_SECONDS )); then
  exit 0
fi

# T030: vừa unlock (SI vừa clear) < N giây → không auto-lock (tránh loop)
if (( LAST_CLEAR > 0 && NOW - LAST_CLEAR < POST_UNLOCK_GRACE )); then
  logger -t secure-input-watchdog "Skip lock: post-unlock grace $((NOW - LAST_CLEAR))s < ${POST_UNLOCK_GRACE}s (pid=$PID)"
  exit 0
fi

# Màn hình đang khóa — không spam lock thêm
if [[ "$(screen_locked)" == "1" ]]; then
  logger -t secure-input-watchdog "Skip lock: screen already locked (pid=$PID)"
  exit 0
fi

# Thông báo (cooldown)
if (( NOW - LAST_NOTIFY >= NOTIFY_COOLDOWN )); then
  osascript -e "display notification \"Secure Input kẹt ${ELAPSED}s (pid $PID / $COMM). Đang khóa màn hình để nhả… Mở bằng MẬT KHẨU.\" with title \"Secure Input Watchdog\"" 2>/dev/null || true
  LAST_NOTIFY=$NOW
fi

# Cooldown sau lần lock trước
if (( NOW - LAST_LOCK < LOCK_COOLDOWN )); then
  write_state "$PID" "$COMM" "$FIRST_SEEN" "$LAST_NOTIFY" "$LAST_LOCK" "$LAST_CLEAR" "$LOCK_FAILURES" "$NOW"
  exit 0
fi

logger -t secure-input-watchdog "Auto-lock: Secure Input stuck ${ELAPSED}s pid=$PID ($COMM)"
python3 - <<'PY' 2>/dev/null || osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}' || true
import ctypes
ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login").SACLockScreenImmediate()
PY

LAST_LOCK=$NOW
LOCK_FAILURES=$((LOCK_FAILURES + 1))
write_state "$PID" "$COMM" "$FIRST_SEEN" "$LAST_NOTIFY" "$LAST_LOCK" "$LAST_CLEAR" "$LOCK_FAILURES" "$NOW"

# Sau nhiều lần lock mà SI cùng PID vẫn kẹt → nhắc Log Out
if (( LOCK_FAILURES >= 3 )); then
  osascript -e "display notification \"Secure Input vẫn kẹt sau ${LOCK_FAILURES} lần khóa (pid $PID). Cân nhắc Log Out (không Restart).\" with title \"Secure Input Watchdog\"" 2>/dev/null || true
fi
