#!/usr/bin/env bash
# Nhả Secure Input kẹt (không Restart, không đụng EVKey).
# Cách duy nhất macOS cho phép khi process khác / loginwindow giữ Secure Input:
#   khóa màn hình → mở khóa bằng MẬT KHẨU → Secure Input thường tắt ngay.
set -euo pipefail

secure_pid() {
  ioreg -l -w 0 2>/dev/null | python3 -c '
import sys,re
raw=sys.stdin.buffer.read().decode("utf-8","replace")
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", raw)
print(m.group(1) if m else "0")
' 2>/dev/null || echo 0
}

# Chỉ kiểm tra — không khóa
if [[ "${1:-}" == "--check" ]]; then
  AFTER=$(secure_pid)
  if [[ "$AFTER" == "0" || -z "$AFTER" ]]; then
    echo "SECURE_INPUT=off OK — tiếp: fix-barrier-keyboard"
    exit 0
  fi
  COMM=$(ps -p "$AFTER" -o comm= 2>/dev/null || echo "zombie/unknown")
  echo "SECURE_INPUT vẫn ACTIVE pid=$AFTER ($COMM) — thử nha-secure-input hoặc Log Out."
  exit 1
fi

BEFORE=$(secure_pid)
if [[ "$BEFORE" == "0" || -z "$BEFORE" ]]; then
  echo "SECURE_INPUT=off — không cần làm gì."
  echo "Nếu Barrier vẫn không gõ sang Win: fix-barrier-keyboard"
  exit 0
fi

COMM=$(ps -p "$BEFORE" -o comm= 2>/dev/null || echo "zombie/unknown")
ETIME=$(ps -p "$BEFORE" -o etime= 2>/dev/null | tr -d ' ' || echo '?')
echo "SECURE_INPUT ACTIVE pid=$BEFORE ($COMM) etime=$ETIME"
echo

# Carbon nudge (chỉ giúp nếu chính process này đang giữ — hầu như không đủ với loginwindow)
python3 - <<'PY' 2>/dev/null || true
import ctypes
lib = ctypes.CDLL("/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox")
for _ in range(8):
    lib.EnableSecureEventInput()
    lib.DisableSecureEventInput()
for _ in range(16):
    lib.DisableSecureEventInput()
PY

# CGSession đã bị Apple gỡ trên macOS mới — dùng SACLockScreenImmediate
echo "Đang khóa màn hình…"
python3 - <<'PY' 2>/dev/null || osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}'
import ctypes
lib = ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login")
lib.SACLockScreenImmediate()
print("locked via SACLockScreenImmediate")
PY

echo
echo "────────────────────────────────────────"
echo "SAU KHI MÀN HÌNH KHÓA — làm lần lượt:"
echo "  1) Mở khóa bằng MẬT KHẨU (tránh Touch ID — Touch ID đôi khi không nhả SI)"
echo "  2) Chạy:  fix-barrier-keyboard"
echo "     hoặc:  fix-barrier-keyboard --wait   # poll đến khi SI tắt rồi restart Barrier"
echo "  3) Nếu vẫn SI=ON (không UI, etime lớn): Apple menu → Log Out"
echo "     (không cần Restart máy) → login lại → fix-barrier-keyboard"
echo "────────────────────────────────────────"
echo
echo "Kiểm tra nhanh sau unlock:  nha-secure-input --check"
