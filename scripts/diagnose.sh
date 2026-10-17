#!/usr/bin/env bash
# Diagnose why Vietnamese typing (EVKey / CGEventTap) fails on macOS.
# Output: machine-readable KEY=value lines + ranked causes at end.
set -euo pipefail

echo "=== DIAGNOSE_VI_TYPING $(date '+%Y-%m-%d %H:%M:%S %z') ==="

# --- EVKey ---
EVKEY_PIDS=$(pgrep -x EVKey 2>/dev/null || true)
if [[ -z "${EVKEY_PIDS}" ]]; then
  EVKEY_PIDS=$(pgrep -f '/EVKeyMac.app/Contents/MacOS/EVKey' 2>/dev/null || true)
fi
if [[ -n "${EVKEY_PIDS}" ]]; then
  echo "EVKEY_RUNNING=yes"
  echo "EVKEY_PIDS=${EVKEY_PIDS//$'\n'/,}"
  ps -p "${EVKEY_PIDS//$'\n'/,}" -o pid=,etime=,%cpu=,command= 2>/dev/null | while read -r line; do
    echo "EVKEY_PROC=${line}"
  done
else
  echo "EVKEY_RUNNING=no"
fi

# --- Secure Input ---
SECURE_PID=$(ioreg -l -w 0 2>/dev/null | python3 -c '
import sys, re
text = sys.stdin.read()
m = re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", text)
print(m.group(1) if m else "0")
' 2>/dev/null || echo "0")
echo "SECURE_INPUT_PID=${SECURE_PID}"
SECURE_NAME=""
SECURE_CMD=""
if [[ "${SECURE_PID}" != "0" && -n "${SECURE_PID}" ]]; then
  SECURE_CMD=$(ps -p "${SECURE_PID}" -o command= 2>/dev/null || echo "unknown")
  SECURE_NAME=$(ps -p "${SECURE_PID}" -o comm= 2>/dev/null || echo "unknown")
  SECURE_ETIME=$(ps -p "${SECURE_PID}" -o etime= 2>/dev/null | tr -d ' ' || true)
  echo "SECURE_INPUT_COMM=${SECURE_NAME}"
  echo "SECURE_INPUT_ETIME=${SECURE_ETIME}"
  echo "SECURE_INPUT_CMD=${SECURE_CMD}"
  echo "SECURE_INPUT_ACTIVE=yes"
else
  echo "SECURE_INPUT_COMM="
  echo "SECURE_INPUT_ACTIVE=no"
fi

# Classify Secure Input holder (+ zombie = PID còn trong ioreg nhưng process đã chết)
SECURE_KIND="none"
SECURE_ZOMBIE=no
SECURE_LOWER=$(printf '%s %s' "${SECURE_NAME}" "${SECURE_CMD}" | tr '[:upper:]' '[:lower:]')
if [[ "${SECURE_PID}" != "0" && -n "${SECURE_PID}" ]]; then
  if ! ps -p "${SECURE_PID}" >/dev/null 2>&1; then
    SECURE_ZOMBIE=yes
    SECURE_KIND="zombie"
  elif echo "${SECURE_LOWER}" | grep -Eq 'iterm2|iterm\.app|/iterm'; then
    SECURE_KIND="iterm"
  elif echo "${SECURE_LOWER}" | grep -Eq 'zentermlite|zenterm'; then
    SECURE_KIND="zenterm"
  elif echo "${SECURE_LOWER}" | grep -Eq 'warp\.app|/warp$|dev\.warp'; then
    SECURE_KIND="warp"
  elif echo "${SECURE_LOWER}" | grep -Eq 'termius'; then
    SECURE_KIND="termius"
  elif echo "${SECURE_LOWER}" | grep -Eq 'cursor\.app|/cursor$'; then
    SECURE_KIND="cursor"
  elif echo "${SECURE_LOWER}" | grep -Eq 'loginwindow|securityagent'; then
    SECURE_KIND="login"
  elif echo "${SECURE_LOWER}" | grep -Eq 'terminal\.app|/terminal[[:space:]]|/utilities/terminal'; then
    SECURE_KIND="terminal"
  elif echo "${SECURE_LOWER}" | grep -Eq 'google chrome|chromium|msedge|arc\.app|firefox|safari|1password|bitwarden'; then
    SECURE_KIND="browser_or_password"
  else
    SECURE_KIND="other"
  fi
fi
echo "SECURE_INPUT_KIND=${SECURE_KIND}"
echo "SECURE_INPUT_ZOMBIE=${SECURE_ZOMBIE}"

# --- Known event-tap rivals / terminals ---
check_proc() {
  local key="$1"
  local pattern="$2"
  local pids
  pids=$(pgrep -f "${pattern}" 2>/dev/null || true)
  if [[ -n "${pids}" ]]; then
    echo "${key}_RUNNING=yes"
    echo "${key}_PIDS=${pids//$'\n'/,}"
  else
    echo "${key}_RUNNING=no"
  fi
}

check_proc "LOGIMGR" "LogiMgrDaemon|/Logi Options|/lghub_agent|/LogiOptionsMgr"
check_proc "LIGHTSHOT" "Lightshot Screenshot.app"
check_proc "ANYDESK" "AnyDesk.app"
check_proc "CHROME_RD" "remoting_me2me_host|chromoting"
check_proc "UNIVERSAL_CONTROL" "UniversalControl.app"
check_proc "ITERM" "iTerm2.app/Contents/MacOS/iTerm2|/Applications/iTerm.app/|/Applications/iTerm2.app/"
check_proc "TERMINAL" "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal|/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"
check_proc "ZENTERM" "ZenTermLite.app|/Applications/ZenTermLite.app/"
check_proc "WARP" "/Applications/Warp.app/|dev.warp.Warp"
check_proc "TERMIUS" "Termius.app|/Applications/Termius.app/"
check_proc "CLAUDE" "/Applications/Claude.app/Contents/MacOS/Claude"
check_proc "CURSOR" "/Applications/Cursor.app/Contents/MacOS/Cursor"
check_proc "VSCODE" "/Applications/Visual Studio Code.app/Contents/MacOS/Electron|/Applications/Visual Studio Code.app/Contents/MacOS/Code"
check_proc "BARRIER" "/Applications/Barrier.app/Contents/MacOS/barrier|/Applications/Barrier.app/Contents/MacOS/barriers|barriers "

CURSOR_HELPERS=$(pgrep -f 'Cursor Helper' 2>/dev/null | wc -l | tr -d ' ')
echo "CURSOR_HELPER_COUNT=${CURSOR_HELPERS}"

# ETIME → phút (ước lượng) cho loginwindow kẹt lâu
etime_to_minutes() {
  local e="${1:-}"
  python3 -c "
e='$e'.strip()
if not e or e=='?':
  print(0); raise SystemExit
parts=e.split('-')
days=0
if len(parts)==2:
  days=int(parts[0]); e=parts[1]
bits=e.split(':')
try:
  bits=[int(x) for x in bits]
except Exception:
  print(0); raise SystemExit
if len(bits)==3: h,m,s=bits
elif len(bits)==2: h,m,s=0,bits[0],bits[1]
else: h,m,s=0,0,bits[0]
print(days*24*60 + h*60 + m)
" 2>/dev/null || echo 0
}
SECURE_MINUTES=0
if [[ -n "${SECURE_ETIME:-}" ]]; then
  SECURE_MINUTES=$(etime_to_minutes "${SECURE_ETIME}")
fi
echo "SECURE_INPUT_MINUTES=${SECURE_MINUTES}"

# --- Ranked causes ---
echo "=== RANKED_CAUSES ==="
rank=0
emit() {
  rank=$((rank + 1))
  echo "CAUSE_${rank}=$1|$2|$3"
}

case "${SECURE_KIND}" in
  zombie)
    emit "HIGH" "secure_input_zombie" "Secure Input KẸT: PID ${SECURE_PID} đã chết nhưng macOS chưa nhả (hay sau Quit Cursor). Chạy: nha-secure-input (mở khóa bằng MẬT KHẨU), hoặc Ctrl+Cmd+Q."
    ;;
  iterm)
    emit "HIGH" "secure_input_iterm" "Secure Input đang bị iTerm/iTerm2 giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Kiểm tra menu iTerm2 → Secure Keyboard Entry (icon chìa khóa) hoặc tab sudo/ssh password."
    ;;
  zenterm)
    emit "HIGH" "secure_input_zenterm" "Secure Input đang bị ZenTermLite giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Quit ZenTermLite hoặc tắt secure keyboard."
    ;;
  warp)
    emit "HIGH" "secure_input_warp" "Secure Input đang bị Warp giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Đóng prompt auth hoặc Quit Warp."
    ;;
  termius)
    emit "HIGH" "secure_input_termius" "Secure Input đang bị Termius giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Đóng dialog password hoặc Quit Termius."
    ;;
  cursor)
    emit "HIGH" "secure_input_cursor" "Secure Input đang bị Cursor giữ (PID ${SECURE_PID}). Đóng ô password/dialog trong Cursor; nếu Quit Cursor mà vẫn lỗi → nha-secure-input."
    ;;
  terminal)
    emit "HIGH" "secure_input_terminal" "Secure Input đang bị Terminal.app giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Bỏ tick Terminal → Secure Keyboard Entry hoặc Quit Terminal."
    ;;
  login)
    if [[ "${SECURE_MINUTES}" -ge 30 ]]; then
      emit "HIGH" "secure_input_login" "Secure Input bị loginwindow/SecurityAgent giữ LÂU (${SECURE_ETIME}, PID ${SECURE_PID}). Thường KHÔNG có dialog. Thử nha-secure-input (mở bằng MẬT KHẨU, tránh Touch ID). Nếu vẫn ON → Apple menu → Log Out (không cần Restart) rồi chạy fix-barrier-keyboard."
    else
      emit "HIGH" "secure_input_login" "Secure Input đang bị loginwindow/SecurityAgent giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Đóng hộp mật khẩu nếu có; không thấy UI → nha-secure-input (mật khẩu, không Touch ID)."
    fi
    ;;
  browser_or_password)
    emit "HIGH" "secure_input" "Secure Input đang bị trình duyệt/password manager giữ (PID ${SECURE_PID}, ${SECURE_NAME}). Blur/đóng ô password."
    ;;
  other)
    emit "HIGH" "secure_input" "Secure Input đang bị giữ bởi PID ${SECURE_PID} (${SECURE_NAME:-unknown}). CGEventTap (EVKey/Barrier) bị macOS chặn đọc phím."
    ;;
esac

# Barrier keyboard is blocked whenever SI is on
if [[ "${SECURE_PID}" != "0" && -n "${SECURE_PID}" ]] && pgrep -f "/Applications/Barrier.app/Contents/MacOS/barriers|barriers -|/Applications/Barrier.app/Contents/MacOS/barrier" >/dev/null 2>&1; then
  emit "HIGH" "barrier_blocked_by_secure_input" "Barrier đang chạy nhưng Secure Input=ON → macOS chặn bàn phím sang Windows (chuột có thể vẫn OK). Nhả SI rồi: fix-barrier-keyboard."
fi

# Active Super/Meta letter remaps in barrier.conf — proven to eat those letters on Mac (2026-10-17)
BARRIER_CONF="${HOME}/barrier.conf"
BARRIER_ACTIVE_REMAPS=0
if [[ -f "$BARRIER_CONF" ]]; then
  BARRIER_ACTIVE_REMAPS=$(grep -E '^[[:space:]]*keystroke\((Super|Meta)\+[a-zA-Z]\)' "$BARRIER_CONF" 2>/dev/null | grep -cv '^[[:space:]]*#' || true)
  # grep -c returns 0 with exit 1 sometimes; normalize
  BARRIER_ACTIVE_REMAPS=${BARRIER_ACTIVE_REMAPS:-0}
fi
echo "BARRIER_CONF_ACTIVE_LETTER_REMAPS=${BARRIER_ACTIVE_REMAPS}"
if [[ "${BARRIER_ACTIVE_REMAPS}" -gt 0 ]]; then
  emit "HIGH" "barrier_letter_remaps" "barrier.conf còn ${BARRIER_ACTIVE_REMAPS} dòng keystroke(Super|Meta+chữ) ACTIVE — trên Mac sẽ mất đúng các chữ đó (A/B 2026-10-17). Comment các dòng đó (xem KEYBOARD-GRABBER-ABTEST.md)."
fi

if [[ -z "${EVKEY_PIDS}" ]]; then
  emit "MED" "evkey_not_running" "EVKey không chạy. Nếu đã dùng Telex hệ thống thì OK cho gõ VN trên Mac; Barrier→Win vẫn cần SI=off."
fi
if pgrep -f "LogiMgrDaemon|/Logi Options" >/dev/null 2>&1; then
  emit "HIGH" "logi_options" "Logi Options / LogiMgrDaemon đang chạy — hay chiếm CGEventTap; khi SI=off vẫn có thể làm mất chữ a/s/v. Fix: fix-keyboard-grabbers --stop"
fi
if pgrep -f "Lightshot Screenshot.app" >/dev/null 2>&1; then
  emit "MED" "lightshot" "Lightshot đang chạy — hay giữ hotkey/event tap toàn cục."
fi
if pgrep -f "AnyDesk.app" >/dev/null 2>&1; then
  emit "MED" "anydesk" "AnyDesk đang chạy — remote input có thể chặn/đụng event tap."
fi
if pgrep -f "remoting_me2me_host|chromoting" >/dev/null 2>&1; then
  emit "HIGH" "chrome_remote_desktop" "Chrome Remote Desktop host đang chạy — có thể nuốt/đụng bàn phím local. Fix: fix-keyboard-grabbers --stop"
fi
# Khi SI=off mà nhiều grabber cùng chạy → cảnh báo pattern mất chữ thường
if [[ "${SECURE_PID}" == "0" || -z "${SECURE_PID}" ]]; then
  GRABBER_N=0
  pgrep -f "LogiMgrDaemon|/Logi Options" >/dev/null 2>&1 && GRABBER_N=$((GRABBER_N + 1))
  pgrep -f "barriers|/Applications/Barrier.app/Contents/MacOS/barrier" >/dev/null 2>&1 && GRABBER_N=$((GRABBER_N + 1))
  pgrep -f "remoting_me2me_host|chromoting" >/dev/null 2>&1 && GRABBER_N=$((GRABBER_N + 1))
  pgrep -f "Lightshot Screenshot.app" >/dev/null 2>&1 && GRABBER_N=$((GRABBER_N + 1))
  if [[ "$GRABBER_N" -ge 2 ]]; then
    emit "HIGH" "keyboard_grabbers_stack" "SI=off nhưng ${GRABBER_N} grabber (Barrier/Logi/ChromeRD/Lightshot) cùng chạy — pattern mất chữ thường (2026-10-17). Nếu không gõ được a/s/v: fix-keyboard-grabbers --stop"
  fi
fi

# Terminal apps running but not holding Secure Input — risk reminders
if [[ "${SECURE_KIND}" != "iterm" ]] && pgrep -f "iTerm2.app/Contents/MacOS/iTerm2|/Applications/iTerm.app/|/Applications/iTerm2.app/" >/dev/null 2>&1; then
  emit "LOW" "iterm_running" "iTerm đang chạy (chưa giữ Secure Input hệ thống). Nếu thấy icon chìa khóa: bỏ tick iTerm2 → Secure Keyboard Entry."
fi
if [[ "${SECURE_KIND}" != "zenterm" ]] && pgrep -f "ZenTermLite.app|/Applications/ZenTermLite.app/" >/dev/null 2>&1; then
  emit "LOW" "zenterm_running" "ZenTermLite đang chạy — cũng có thể bật secure keyboard / giữ Secure Input sau khi auth."
fi
if [[ "${SECURE_KIND}" != "warp" ]] && pgrep -f "/Applications/Warp.app/|dev.warp.Warp" >/dev/null 2>&1; then
  emit "LOW" "warp_running" "Warp đang chạy — auth/password prompt có thể bật Secure Input."
fi
if [[ "${SECURE_KIND}" != "termius" ]] && pgrep -f "Termius.app|/Applications/Termius.app/" >/dev/null 2>&1; then
  emit "LOW" "termius_running" "Termius đang chạy — SSH password UI có thể bật Secure Input."
fi

if [[ "${CURSOR_HELPERS}" -gt 80 ]]; then
  emit "MED" "cursor_heavy" "Cursor Helper count=${CURSOR_HELPERS} (rất cao) — nhiều cửa sổ Electron làm EVKey dễ kẹt."
fi
if pgrep -f "/Applications/Claude.app/Contents/MacOS/Claude" >/dev/null 2>&1; then
  emit "LOW" "claude_desktop" "Claude Desktop đang chạy (Electron) — thêm tải event/accessibility."
fi
if [[ "${rank}" -eq 0 ]]; then
  emit "LOW" "unknown" "Không thấy Secure Input / Logi / EVKey down. Kiểm tra Accessibility cho EVKey trong System Settings."
fi

echo "=== FIX_HINTS ==="
echo "HINT_1=Nhả SI: nha-secure-input hoặc Ctrl+Cmd+Q — mở khóa bằng MẬT KHẨU (tránh Touch ID)."
echo "HINT_2=loginwindow kẹt lâu / không UI: Log Out (không Restart) → fix-barrier-keyboard."
echo "HINT_3=Barrier phím Win: chỉ hoạt động khi SECURE_INPUT_ACTIVE=no; chạy fix-barrier-keyboard."
echo "HINT_4=iTerm icon chìa khóa: bỏ tick iTerm2 → Secure Keyboard Entry."
echo "HINT_5=Gõ VN trên Mac: ưu tiên Telex hệ thống nếu EVKey hay chết; EVKey cần SI=off."
echo "HINT_6=Watchdog: bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/install-secure-input-watchdog.sh"
echo "HINT_7=SI=off mà mất chữ a/s/v: fix-keyboard-grabbers [--stop] (Barrier/Logi/ChromeRD/Lightshot)."
echo "HINT_8=Docs: CONTEXT.md + CHECKLIST-NHA-SI.md + specs/001-secure-input-release/."
echo "=== END ==="
