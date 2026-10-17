#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
  echo "NOTE: CGSession vẫn tồn tại"
else
  echo "OK: CGSession absent"
fi
python3 - <<'PY'
import ctypes, sys
lib = ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login")
assert hasattr(lib, "SACLockScreenImmediate")
print("OK: SACLockScreenImmediate loadable")
PY
for f in nha-secure-input.sh secure-input-watchdog.sh fix-barrier-keyboard.sh fix-nhanh.sh; do
  p="$ROOT/scripts/$f"
  if grep -q 'CGSession' "$p" 2>/dev/null && ! grep -q 'SACLockScreenImmediate' "$p" 2>/dev/null; then
    echo "FAIL: $f CGSession-only"; fail=1
  else
    echo "OK: $f"
  fi
done
exit "$fail"
