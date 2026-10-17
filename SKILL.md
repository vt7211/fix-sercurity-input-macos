---
name: kiem-tra-go-tieng-viet
description: >-
  Chẩn đoán & nhả lỗi không gõ được tiếng Việt / Barrier bàn phím trên macOS
  (Secure Input, loginwindow kẹt, EVKey, Telex, iTerm, Barrier→Windows, AnyDesk,
  Logi, Lightshot). Use when: không gõ được tiếng Việt, EVKey hỏng, Barrier không
  gõ sang Windows, Secure Input kẹt, Telex/VNI chết, hoặc làm việc trong workspace
  skill này (Speckit 001-secure-input-release).
---

# Kiểm tra gõ tiếng Việt + Secure Input + Barrier

## Đọc trước (bắt buộc khi sửa lỗi lâu dài)

1. [CONTEXT.md](CONTEXT.md) — lịch sử sự cố, giới hạn macOS, quyết định đã chốt  
2. [REFERENCE.md](REFERENCE.md) — lệnh / API khóa màn hình  
3. [specs/001-secure-input-release/spec.md](specs/001-secure-input-release/spec.md) — Speckit P0  
4. `.specify/memory/constitution.md` — nguyên tắc nhả SI  

Workspace: mở `kiem-tra-go-tieng-viet.code-workspace` (thư mục skill này).

## Khi nào dùng

- Không gõ được tiếng Việt / EVKey / Telex  
- **Barrier chuột OK nhưng không gõ được sang Windows**  
- Secure Input kẹt không thấy dialog password  
- **SI=off nhưng không gõ được chữ thường (`a`/`s`/`v`) hoặc thiếu ký tự** → grabbers, không phải SI  
- User bảo “lỗi này lâu rồi, đừng chỉ bảo Restart”
## Bắt buộc làm ngay

```bash
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/diagnose.sh
```

Nguyên nhân chính = `CAUSE_1` mức HIGH nếu có.

### Phân nhánh nhanh

| Quan sát | Hướng |
|----------|--------|
| `SECURE_INPUT_ACTIVE=yes` | `nha-secure-input` → Log Out nếu deep-stuck |
| SI=off, mất chữ trên **Mac** | Kiểm `~/barrier.conf` còn `keystroke(Super\|Meta+chữ)` ACTIVE không — comment hết. Escape: `fix-keyboard-grabbers --stop` |
| SI=off, chỉ phím sang **Win** hỏng | `fix-barrier-keyboard` |
### User nhờ sửa / Barrier không gõ sang Win

```bash
# 1) Trạng thái Barrier vs Secure Input
fix-barrier-keyboard

# 2) Nếu BLOCKED — nhả SI (khóa màn hình; mở bằng MẬT KHẨU, tránh Touch ID)
nha-secure-input
# hoặc: fix-barrier-keyboard --lock

# 3) Sau unlock — poll SI rồi restart Barrier, hoặc kiểm tra tay:
fix-barrier-keyboard --wait
#    nha-secure-input --check
# 4) Nếu vẫn SI=on (loginwindow ETIME lớn / không UI):
#    → bảo user Log Out (Apple menu). Không hứa soft-fix.
#    Chi tiết: CHECKLIST-NHA-SI.md
# 5) Sau SI=off (nếu chưa dùng --wait):
fix-barrier-keyboard
```
Soft fix EVKey (optional; mặc định không ép mở EVKey nếu đang dùng Telex):

```bash
fix-go-tieng-viet
fix-go-tieng-viet --lock
fix-go-tieng-viet --evkey
```

## Kiến thức lõi (không được bỏ qua)

### Secure Input chặn tuyệt đối

`kCGSSessionSecureInputPID ≠ 0` → macOS chặn **CGEventTap** toàn session:

| Nạn nhân | Hậu quả khi SI=on |
|----------|-------------------|
| EVKey | Không gõ VN |
| Barrier (`barriers`) | **Không gửi phím** sang Win (chuột thường vẫn OK) |
| Phần mềm KVM bắt phím khác | Tương tự |

**Không có API public** để Disable Secure Input của process khác.  
Carbon `DisableSecureEventInput` chỉ giảm nest count của **process gọi**.

### Thứ tự nhả (constitution III)

1. Đóng password UI / Quit app giữ PID  
2. `nha-secure-input` / Ctrl+Cmd+Q → unlock **password** (tránh Touch ID)  
3. **Log Out** nếu `loginwindow` kẹt nhiều giờ / soft lock không đổi PID  
4. Restart máy — cuối cùng  

### Khóa màn hình trên macOS mới

**KHÔNG** dùng  
`/System/Library/CoreServices/Menu Extras/User.menu/.../CGSession`  
(path đã biến mất → script cũ fail im lặng).

Dùng:

```text
login.framework → SACLockScreenImmediate()
```

(đã gắn trong `nha-secure-input.sh`, watchdog, `fix-*-*.sh`).

### Hai kiểu “Secure” dễ nhầm

| Kiểu | Dấu hiệu | Tắt |
|------|----------|-----|
| iTerm Secure Keyboard Entry | Icon chìa khóa cửa sổ | Menu iTerm2 → Secure Keyboard Entry |
| macOS Secure Input | `ioreg` PID ≠ 0 | Theo thứ tự nhả ở trên |

### Gõ tiếng Việt

- **Ổn định:** VietnameseIM **Telex** hệ thống (không phụ thuộc CGEventTap như EVKey).  
- EVKey: chỉ khi user còn dùng; skill không bắt buộc restart EVKey.

### AnyDesk

Trên máy đã xử lý (2026-10-17): LaunchAgent/Daemon AnyDesk `Disabled` + `RunAtLoad=false`.  
Remote/AnyDesk vẫn có thể tranh tap nếu user mở tay.

### Watchdog

`com.user.secure-input-watchdog` — mỗi 30s; cùng PID ≥ 90s → notify + auto-lock.  
Grace 60s sau khi SI vừa tắt (tránh loop); SI off + `barriers` chết → mở Barrier.  
State: `~/.local/state/secure-input-watchdog/last.json` — `scripts/validate-watchdog-state.sh`.  
Cài: `scripts/install-secure-input-watchdog.sh`.

## Báo cáo cho user (mẫu)

```markdown
**Nguyên nhân chính:** <CAUSE_1>

| Mức | Mã | Chi tiết |
|-----|-----|----------|
| HIGH/MED/LOW | code | ... |

**Cách xử lý:**
1. ...
2. ...
```

- Nêu **process + PID + ETIME**.  
- Nếu Barrier: nói rõ “phím bị SI chặn, chuột có thể vẫn được”.  
- Nếu loginwindow deep-stuck: **Log Out**, không vòng vo Accessibility.

## Fix theo mã

| Mã | Fix |
|----|-----|
| `secure_input_login` | Đóng dialog nếu có; không có UI + ETIME lớn → `nha-secure-input` rồi **Log Out** nếu vẫn on |
| `secure_input` / zombie | `nha-secure-input` / `--lock` |
| `secure_input_iterm` | Bỏ tick iTerm Secure Keyboard Entry |
| `secure_input_terminal` / `_zenterm` / `_warp` / `_termius` | Tắt menu / Quit app → diagnose lại |
| `evkey_not_running` | Nếu user dùng Telex: OK bỏ qua; nếu cần EVKey: mở EVKeyMac / `--evkey` |
| `lightshot` / `anydesk` / `logi_options` | Quit / `fix-keyboard-grabbers --stop` |
| `chrome_remote_desktop` / `keyboard_grabbers_stack` | `fix-keyboard-grabbers --stop` rồi test `asv123` trên Mac |
| Barrier phím fail + SI=on | Không restart Barrier trước; nhả SI rồi `fix-barrier-keyboard` |
| Mất chữ + SI=off | Thường do **Barrier** + `barrier.conf` remap `Super/Meta+a/s/v`. Tắt các dòng đó (đã làm 2026-10-17) hoặc `fix-keyboard-grabbers --stop`. Logi alone = OK. |## Speckit trong skill này

Đã `specify init` (cursor-agent). Làm việc P0:

```text
/speckit-plan   → specs/001-secure-input-release/
/speckit-tasks
/speckit-implement
```

Mọi phát hiện mới → cập nhật CONTEXT.md + spec (constitution VI).

## Sau khi sửa

Chạy lại `diagnose.sh`. Thành công khi:

- `SECURE_INPUT_ACTIVE=no` (hoặc PID=0)  
- Nếu cần Barrier: `fix-barrier-keyboard` → gõ được sang Win  
- Không bắt buộc `EVKEY_RUNNING=yes` nếu user dùng Telex  
