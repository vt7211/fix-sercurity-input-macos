# REFERENCE — API & lệnh nhanh

## Đọc Secure Input

```bash
# PID holder
ioreg -l -w 0 | python3 -c '
import sys,re
m=re.search(r"kCGSSessionSecureInputPID[\"\s=]+(\d+)", sys.stdin.read())
print(m.group(1) if m else 0)'

# Boolean
python3 -c 'import ctypes; print(ctypes.CDLL(
"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox"
).IsSecureEventInputEnabled())'
```

## Khóa màn hình (macOS mới — KHÔNG dùng CGSession)

```python
import ctypes
ctypes.CDLL("/System/Library/PrivateFrameworks/login.framework/login").SACLockScreenImmediate()
```

Hoặc: **Ctrl+Cmd+Q**. Mở khóa bằng **mật khẩu**, tránh Touch ID khi đang debug SI.

## Lệnh skill

```bash
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/diagnose.sh
nha-secure-input
nha-secure-input --check     # chỉ kiểm tra SI, không khóa
fix-barrier-keyboard
fix-barrier-keyboard --lock
fix-barrier-keyboard --wait      # poll SI tắt (mặc định 90s) rồi restart Barrier
fix-barrier-keyboard --wait 120
fix-keyboard-grabbers           # SI=off, mất chữ: report + soft
fix-keyboard-grabbers --stop    # stop Barrier/Logi/ChromeRD/Lightshot
fix-keyboard-grabbers --restore
fix-go-tieng-viet          # soft fix
fix-go-tieng-viet --lock    # + khóa màn hình
```

### Pattern: mất chữ thường khi SI=off (2026-10-17)

Không gõ được `a`/`s`/`v` trên Mac dù `IsSecureEventInputEnabled=0`.

**A/B + conf test:**

| Điều kiện | Kết quả |
|-----------|---------|
| Logi alone | OK |
| Barrier + bất kỳ remap Super/Meta+**chữ** | FAIL (đúng chữ đó) |
| Barrier + **tắt hết** Super/Meta keystroke map | OK (`asv` + `cxz`) |

Fix giữ: comment toàn bộ `keystroke(Super\|Meta+…)` trong `~/barrier.conf`.  
Backup: `~/barrier.conf.bak-asv-20261017`. Escape: `fix-keyboard-grabbers --stop`.  
Chi tiết: `specs/001-secure-input-release/KEYBOARD-GRABBER-ABTEST.md`.
Checklist vận hành: [CHECKLIST-NHA-SI.md](CHECKLIST-NHA-SI.md).
## Watchdog

```bash
# Cài / cập nhật
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/install-secure-input-watchdog.sh

# Trạng thái
launchctl print "gui/$(id -u)/com.user.secure-input-watchdog" | head -40

# Log
tail -f ~/Library/Logs/secure-input-watchdog.log

# Gỡ
launchctl bootout "gui/$(id -u)/com.user.secure-input-watchdog"
rm -f ~/Library/LaunchAgents/com.user.secure-input-watchdog.plist
```

Env (LaunchAgent / shell):

| Biến | Mặc định | Nghĩa |
|------|----------|--------|
| `SECURE_INPUT_STUCK_SECONDS` | 90 | Cùng PID ≥ N giây → notify + lock |
| `SECURE_INPUT_POST_UNLOCK_GRACE` | 60 | Sau khi SI vừa tắt, không auto-lock trong N giây |
| `SECURE_INPUT_REOPEN_BARRIER` | 1 | SI off + `barriers` chết → `open -a Barrier` |
| `SECURE_INPUT_LOCK_COOLDOWN` | 120 | Khoảng cách tối thiểu giữa hai lần auto-lock |
| `SECURE_INPUT_NOTIFY_COOLDOWN` | 300 | Khoảng cách giữa hai notification |

State file: `~/.local/state/secure-input-watchdog/last.json`  
Schema: `scripts/watchdog-state.schema.json`  
Validate: `bash scripts/validate-watchdog-state.sh [--self-test]`

## AnyDesk autostart (đã áp dụng máy này)

Plists:

- `/Library/LaunchAgents/com.philandro.anydesk.Frontend.plist`
- `/Library/LaunchDaemons/com.philandro.anydesk.service.plist`

Đặt `Disabled=true`, `RunAtLoad=false` (cần admin). Helper có thể giữ.

Bật lại: sửa plist ngược lại + `launchctl bootstrap` / mở app AnyDesk.

## Barrier

- App: `/Applications/Barrier.app`
- Conf user: `~/barrier.conf`
- Khi SI on: **không** gửi phím — đây là expected macOS behavior
- Sau SI off: `fix-barrier-keyboard` (killall + `open -a Barrier`)

## Phân biệt hai “Secure”

| Tên | Scope | Check |
|-----|-------|-------|
| iTerm Secure Keyboard Entry | Menu app | Icon chìa khóa cửa sổ iTerm |
| macOS Secure Input | Toàn session | `kCGSSessionSecureInputPID` |

## App hay liên quan

loginwindow, SecurityAgent, Cursor/Electron, iTerm, ZenTermLite, Warp, Termius, Lightshot, AnyDesk, LogiMgrDaemon, Barrier (`barriers`).
