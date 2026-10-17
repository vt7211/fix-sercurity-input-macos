#!/usr/bin/env bash
# Barrier → Windows: bàn phím bị chặn khi Secure Input = ON.
# Script này: báo trạng thái → nếu SI off thì restart Barrier; nếu SI on thì hướng dẫn nhả.
#
# Usage:
#   fix-barrier-keyboard           # check + restart Barrier nếu SI off
#   fix-barrier-keyboard --lock    # khóa màn hình rồi exit (user unlock bằng mật khẩu)
#   fix-barrier-keyboard --wait    # poll SI đến khi off (mặc định 90s) rồi restart Barrier
#   fix-barrier-keyboard --wait 120
set -euo pipefail

secure_pid() {
  ioreg -l -w 0 2>/dev/null | python3 -c '
import sys,re
raw=sys.stdin.buffer.read().decode("utf-8","replace")
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", raw)
print(m.group(1) if m else "0")
' 2>/dev/null || echo 0
}

restart_barrier() {
  echo "SECURE_INPUT=off OK — restart Barrier…"
  killall barriers barrierc barrier 2>/dev/null || true
  sleep 1
  open -a Barrier
  sleep 2
  if pgrep -lf barriers >/dev/null 2>&1; then
    pgrep -lf barriers
  else
    echo "WARN: barriers chưa chạy — bấm Start trong Barrier UI"
  fi
  echo "Thử gõ sang Windows ngay."
  echo "=== DONE ==="
}

print_blocked_help() {
  local si="$1"
  local comm etime
  comm=$(ps -p "$si" -o comm= 2>/dev/null || echo zombie)
  etime=$(ps -p "$si" -o etime= 2>/dev/null || echo '?')
  echo "BLOCKED: Secure Input ON pid=$si ($comm) etime=$etime"
  echo
  echo "Barrier KHÔNG gửi được phím sang Win khi Secure Input bật (giới hạn macOS)."
  echo "Cách nhả (nhẹ → nặng):"
  echo "  1) Ctrl+Cmd+Q → mở khóa bằng MẬT KHẨU (không dùng Touch ID)"
  echo "     hoặc: nha-secure-input"
  echo "  2) Nếu vẫn ON sau unlock: Apple menu → Log Out (không cần Restart máy)"
  echo "  3) Sau khi SI = off, chạy lại: fix-barrier-keyboard"
  echo "     hoặc chờ tự động: fix-barrier-keyboard --wait"
}

WAIT_MODE=0
WAIT_SECS=90
DO_LOCK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_MODE=1
      if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        WAIT_SECS="$2"
        shift
      fi
      ;;
    --lock)
      DO_LOCK=1
      ;;
    -h|--help)
      echo "Usage: fix-barrier-keyboard [--lock] [--wait [SECONDS]]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1 (try --help)" >&2
      exit 1
      ;;
  esac
  shift
done

echo "=== BARRIER_KEYBOARD $(date '+%H:%M:%S') ==="

SI=$(secure_pid)

if [[ "$SI" != "0" && -n "$SI" ]]; then
  print_blocked_help "$SI"

  if [[ "$DO_LOCK" -eq 1 ]]; then
    echo
    echo "→ Đang khóa màn hình… mở bằng MẬT KHẨU (tránh Touch ID), rồi chạy lại script này"
    echo "  (hoặc: fix-barrier-keyboard --wait)."
    python3 - <<'PY' 2>/dev/null || osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}'
import ctypes
ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login").SACLockScreenImmediate()
PY
  fi

  if [[ "$WAIT_MODE" -eq 1 ]]; then
    echo
    echo "Đang chờ Secure Input tắt (tối đa ${WAIT_SECS}s, poll mỗi 2s)…"
    echo "Mở khóa bằng MẬT KHẨU nếu màn hình đang khóa."
    elapsed=0
    while (( elapsed < WAIT_SECS )); do
      sleep 2
      elapsed=$((elapsed + 2))
      SI=$(secure_pid)
      if [[ "$SI" == "0" || -z "$SI" ]]; then
        echo "SI cleared sau ~${elapsed}s."
        restart_barrier
        exit 0
      fi
      if (( elapsed % 10 == 0 )); then
        echo "  … vẫn ON pid=$SI (${elapsed}s/${WAIT_SECS}s)"
      fi
    done
    echo
    echo "TIMEOUT ${WAIT_SECS}s — Secure Input vẫn ON."
    echo "→ Apple menu → Log Out (không Restart) → login → fix-barrier-keyboard"
    exit 2
  fi

  exit 2
fi

restart_barrier
