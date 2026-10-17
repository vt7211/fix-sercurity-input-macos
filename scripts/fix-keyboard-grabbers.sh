#!/usr/bin/env bash
# Khi SI=off nhưng Mac vẫn không gõ được chữ thường (a/s/v…) hoặc thiếu ký tự.
# Pattern 2026-10-17: chồng CGEventTap / remote / KVM — không phải Secure Input.
#
# Usage:
#   fix-keyboard-grabbers           # report + soft (quit Lightshot, U.S. layout)
#   fix-keyboard-grabbers --stop    # stop Barrier, ChromeRD, Logi, Lightshot
#   fix-keyboard-grabbers --restore # hướng dẫn bật lại
set -euo pipefail

MODE="${1:-}"

si_pid() {
  ioreg -l -w 0 2>/dev/null | python3 -c '
import sys,re
raw=sys.stdin.buffer.read().decode("utf-8","replace")
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", raw)
print(m.group(1) if m else "0")
' 2>/dev/null || echo 0
}

switch_us_layout() {
  python3 - <<'PY' 2>/dev/null || true
import ctypes
from ctypes import c_void_p, c_char_p, c_bool, c_uint32

cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
hi = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox")
cf.CFStringCreateWithCString.restype = c_void_p
cf.CFStringCreateWithCString.argtypes = [c_void_p, c_char_p, c_uint32]
cf.CFRelease.argtypes = [c_void_p]
cf.CFArrayGetCount.argtypes = [c_void_p]
cf.CFArrayGetCount.restype = ctypes.c_long
cf.CFArrayGetValueAtIndex.argtypes = [c_void_p, ctypes.c_long]
cf.CFArrayGetValueAtIndex.restype = c_void_p
cf.CFStringGetCString.argtypes = [c_void_p, c_char_p, ctypes.c_long, c_uint32]
cf.CFStringGetCString.restype = c_bool
hi.TISCreateInputSourceList.restype = c_void_p
hi.TISCreateInputSourceList.argtypes = [c_void_p, c_bool]
hi.TISGetInputSourceProperty.restype = c_void_p
hi.TISGetInputSourceProperty.argtypes = [c_void_p, c_void_p]
hi.TISSelectInputSource.argtypes = [c_void_p]
hi.TISSelectInputSource.restype = c_uint32

key = cf.CFStringCreateWithCString(None, b"TISPropertyInputSourceID", 0x08000100)
sources = hi.TISCreateInputSourceList(None, True)
if not sources:
    raise SystemExit(0)
buf = ctypes.create_string_buffer(256)
n = cf.CFArrayGetCount(sources)
for i in range(n):
    src = cf.CFArrayGetValueAtIndex(sources, i)
    prop = hi.TISGetInputSourceProperty(src, key)
    if prop and cf.CFStringGetCString(prop, buf, 256, 0x08000100):
        sid = buf.value.decode()
        if sid in ("com.apple.keylayout.US", "com.apple.keylayout.ABC"):
            hi.TISSelectInputSource(src)
            print("INPUT_LAYOUT=US/ABC")
            break
cf.CFRelease(sources)
cf.CFRelease(key)
PY
}

status_line() {
  local name="$1" pattern="$2"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    echo "  ON  $name"
  else
    echo "  off $name"
  fi
}

echo "=== KEYBOARD_GRABBERS $(date '+%H:%M:%S') ==="
SI=$(si_pid)
echo "SECURE_INPUT_PID=$SI"
if [[ "$SI" != "0" && -n "$SI" ]]; then
  echo "NOTE: Secure Input đang ON — ưu tiên nha-secure-input / Log Out trước."
  echo "      Script này xử lý case SI=off mà vẫn mất chữ."
fi

echo
echo "Grabbers (nghi nuốt phím khi SI=off):"
status_line "Barrier" "barriers|/Applications/Barrier.app/Contents/MacOS/barrier"
status_line "Logi Options (LogiMgrDaemon)" "LogiMgrDaemon|/Logi Options"
status_line "Lightshot" "Lightshot Screenshot.app"
status_line "Chrome Remote Desktop" "remoting_me2me_host|chromoting"
status_line "Universal Control" "UniversalControl.app"
status_line "AnyDesk" "AnyDesk.app"

if [[ "$MODE" == "--restore" ]]; then
  echo
  echo "RESTORE khi gõ đã OK:"
  echo "  open -a Barrier"
  echo "  launchctl enable \"gui/\$(id -u)/com.logitech.manager.daemon\" 2>/dev/null"
  echo "  launchctl bootstrap \"gui/\$(id -u)\" /Library/LaunchAgents/com.logitech.manager.daemon.plist"
  echo "  # ChromeRD / Lightshot: chỉ bật nếu cần"
  exit 0
fi

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  echo "Usage: fix-keyboard-grabbers [--stop|--restore]"
  exit 0
fi

if [[ "$MODE" != "--stop" ]]; then
  echo
  echo "Soft steps:"
  if killall "Lightshot Screenshot" 2>/dev/null; then
    echo "  - quit Lightshot"
  else
    echo "  - Lightshot: already off"
  fi
  switch_us_layout
  echo "  - layout → U.S./ABC (tránh Telex nuốt a/s khi IME kẹt)"
  echo
  echo "Nếu vẫn không gõ được chữ thường:"
  echo "  fix-keyboard-grabbers --stop"
  echo "Rồi click ô text trên Mac, gõ: asv123"
  exit 0
fi

echo
echo "STOP mode — ưu tiên Barrier (thủ phạm A/B 2026-10-17), rồi grabber khác:"

# 1) Barrier FIRST — confirmed: alone causes missing a/s/v on Mac
osascript -e 'tell application "Barrier" to quit' 2>/dev/null || true
killall barriers barrierc barrier Barrier 2>/dev/null && echo "  - Barrier stopped (primary fix)" || echo "  - Barrier: off"

killall "Lightshot Screenshot" 2>/dev/null && echo "  - Lightshot quit" || echo "  - Lightshot: off"

launchctl bootout "gui/$(id -u)/org.chromium.chromoting" 2>/dev/null || true
killall remoting_me2me_host remoting_me2me_host_service remoting_agent_process_broker 2>/dev/null \
  && echo "  - ChromeRD stopped" || echo "  - ChromeRD: off"

# Logi: A/B = OK alone; vẫn tắt nếu user truyền --stop-all (default: để Logi nếu đang chạy)
# Giữ tương thích: vẫn bootout Logi vì stack cũ; comment trong log
if [[ "${FIX_GRABBERS_KEEP_LOGI:-0}" != "1" ]]; then
  if [[ -f /Library/LaunchAgents/com.logitech.manager.daemon.plist ]]; then
    launchctl bootout "gui/$(id -u)/com.logitech.manager.daemon" 2>/dev/null || true
    # Không disable vĩnh viễn — Logi không phải thủ phạm; chỉ bootout session
  fi
  killall LogiMgrDaemon LogiMgrUpdater "Logi Options" "Logi Options+" 2>/dev/null || true
  sleep 1
  pgrep -f "LogiMgrDaemon" >/dev/null 2>&1 && echo "  - Logi: vẫn chạy" || echo "  - Logi: stopped (A/B: không phải thủ phạm; bật lại OK)"
fi

switch_us_layout
echo "  - layout → U.S./ABC"

echo
echo "Thủ phạm đã confirm: Barrier. Test: gõ asv123 trên Mac."
echo "  ok   → khi cần Win: open -a Barrier (nếu Mac mất chữ lại → Stop Barrier)"
echo "  fail → báo agent (không còn chỉ Barrier)"
echo "=== DONE ==="
